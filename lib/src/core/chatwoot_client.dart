import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/chatwoot_repository.dart';
import '../data/local/instance_key.dart';
import '../data/local/local_storage.dart';
import '../data/models/chatwoot_user.dart';
import '../data/remote/api/chatwoot_client_api_interceptor.dart';
import '../data/remote/api/chatwoot_client_auth_service.dart';
import '../data/remote/api/chatwoot_client_service.dart';
import '../data/remote/api/requests/chatwoot_new_message_request.dart';
import '../data/remote/realtime/chatwoot_action_data.dart';
import '../data/remote/realtime/chatwoot_socket.dart';
import '../shared/sdk_log.dart';
import '../shared/url_policy.dart';
import 'chatwoot_callbacks.dart';
import 'chatwoot_client_exception.dart';
import 'chatwoot_upload.dart';

/// Represents a chatwoot client instance. All chatwoot operations (Example: sendMessages) are
/// passed through chatwoot client. For more info visit
/// https://www.chatwoot.com/docs/product/channels/api/client-apis
///
/// {@category FlutterClientSdk}
class ChatwootClient {
  final ChatwootRepository _repository;
  final List<Dio> _dios;
  bool _disposed = false;

  final String baseUrl;
  final String inboxIdentifier;
  final ChatwootCallbacks? callbacks;
  final ChatwootUser? user;

  ChatwootClient._(
    this._repository,
    this._dios, {
    required this.baseUrl,
    required this.inboxIdentifier,
    this.user,
    this.callbacks,
  });

  /// Builds a client around an existing [repository]. Tests only.
  @visibleForTesting
  ChatwootClient.withRepository(
    ChatwootRepository repository, {
    required this.baseUrl,
    required this.inboxIdentifier,
    this.user,
    this.callbacks,
  }) : _repository = repository,
       _dios = const [];

  /// Retrieves chatwoot client's messages. If persistence is enabled
  /// [ChatwootCallbacks.onPersistedMessagesRetrieved] will be triggered with
  /// persisted messages. On successfully fetch from remote server
  /// [ChatwootCallbacks.onMessagesRetrieved] will be triggered. Completes once
  /// the remote fetch finished.
  Future<void> loadMessages() async {
    _repository.getPersistedMessages();
    await _repository.getMessages();
  }

  /// Sends chatwoot message. The echoId is your temporary message id. When message sends successfully
  /// [ChatwootMessage] will be returned with the [echoId] on [ChatwootCallbacks.onMessageSent]. If
  /// message fails to send [ChatwootCallbacks.onError] will be triggered [echoId] as data.
  ///
  /// [attachments] (images, files, voice; at most [ChatwootUpload.maxSize]
  /// each) go with the message; [content] may then be empty.
  Future<void> sendMessage({
    required String content,
    required String echoId,
    List<ChatwootUpload> attachments = const [],
  }) async {
    final request = ChatwootNewMessageRequest(content: content, echoId: echoId);
    await _repository.sendMessage(request, attachments: attachments);
  }

  /// Send chatwoot action performed by user.
  ///
  /// Example: User started typing. Completes with `false` when the action
  /// could not be sent (the realtime connection is not subscribed).
  Future<bool> sendAction(ChatwootActionType action) async =>
      _repository.sendAction(action);

  /// Disposes chatwoot client: cancels stream subscriptions and timers and
  /// closes the HTTP clients. Safe to call more than once.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _repository.dispose();
    for (final dio in _dios) {
      dio.close(force: true);
    }
  }

  /// Clears this client's conversation and messages. The contact and user are kept.
  Future<void> clearClientData() =>
      _repository.clear(clearChatwootUserStorage: false);

  /// Creates an instance of [ChatwootClient] with the [baseUrl] of your chatwoot installation,
  /// [inboxIdentifier] for the targeted inbox. Specify custom user details using [user] and [callbacks] for
  /// handling chatwoot events. By default persistence is enabled, to disable persistence set [enablePersistence] as false.
  ///
  /// [baseUrl] must be https; plain http is only accepted for localhost /
  /// 10.0.2.2, or for any host when [allowInsecure] is true (development only).
  /// An invalid [baseUrl] throws an [ArgumentError].
  ///
  /// Completes once the initial contact and conversation refresh finished.
  /// Failures during that refresh are reported through [ChatwootCallbacks.onError]
  /// instead of being thrown. If local storage cannot be opened the client
  /// still works, without persistence, and reports `STORAGE_FAILED`.
  ///
  /// Each client owns its storage: clients without persistence never share state,
  /// persisted clients with the same [getClientInstanceKey] share the persisted
  /// contact, conversation and messages. Persisted data is encrypted at rest;
  /// the user's `identifierHash` and `customAttributes` are never written to disk.
  static Future<ChatwootClient> create({
    required String baseUrl,
    required String inboxIdentifier,
    ChatwootUser? user,
    bool enablePersistence = true,
    bool allowInsecure = false,
    ChatwootCallbacks? callbacks,
  }) async {
    validateBaseUrl(baseUrl, allowInsecure: allowInsecure);
    final cableUrl = chatwootCableUri(baseUrl);

    var storage = LocalStorage.inMemory();
    if (enablePersistence) {
      try {
        await LocalStorage.openDB();
        storage = LocalStorage.persisted(
          getClientInstanceKey(
            baseUrl: baseUrl,
            inboxIdentifier: inboxIdentifier,
            userIdentifier: user?.identifier,
            identifierHash: user?.identifierHash,
          ),
        );
      } catch (e) {
        sdkLog('persistence unavailable: $e');
        callbacks?.onError?.call(
          e is ChatwootClientException
              ? e
              : ChatwootClientException(
                  'local storage unavailable, continuing without persistence: $e',
                  ChatwootClientExceptionType.STORAGE_FAILED,
                ),
        );
      }
    }

    late final ChatwootRepositoryImpl repository;
    final authDio = Dio(BaseOptions(baseUrl: baseUrl));
    final dio = Dio(BaseOptions(baseUrl: baseUrl))
      ..interceptors.add(
        ChatwootClientApiInterceptor(
          inboxIdentifier,
          storage,
          ChatwootClientAuthServiceImpl(dio: authDio),
          onSessionReset: () => repository.onSessionReset(),
        ),
      );

    repository = ChatwootRepositoryImpl(
      clientService: ChatwootClientServiceImpl(dio: dio),
      socket: ChatwootSocket(
        url: cableUrl,
        tokenProvider: () => storage.contact.get()?.pubsubToken,
      ),
      localStorage: storage,
      streamCallbacks: callbacks ?? ChatwootCallbacks(),
    );

    final client = ChatwootClient._(
      repository,
      [authDio, dio],
      baseUrl: baseUrl,
      inboxIdentifier: inboxIdentifier,
      user: user,
      callbacks: callbacks,
    );

    await repository.initialize(user);
    return client;
  }

  /// Creates a chatwoot client instance key using the chatwoot client instance baseurl, inboxIdentifier
  /// and userIdentifier. Client instance keys are used to differentiate between client instances and their data
  /// (contact, conversation and messages).
  ///
  /// Separate persisted [ChatwootClient] instances with same baseUrl, inboxIdentifier and userIdentifier
  /// are regarded as the same and therefore use the same contact and conversation.
  /// The same identifier with a different [identifierHash] is a different instance.
  static String getClientInstanceKey({
    required String baseUrl,
    required String inboxIdentifier,
    String? userIdentifier,
    String? identifierHash,
  }) => chatwootInstanceKey(
    baseUrl: baseUrl,
    inboxIdentifier: inboxIdentifier,
    userIdentifier: userIdentifier,
    identifierHash: identifierHash,
  );

  /// Clears all persisted chatwoot data on device for a particular chatwoot client instance.
  /// See [getClientInstanceKey] on how chatwoot client instances are differentiated
  /// (pass the same [identifierHash] the client was created with).
  /// Can be called before any client was created (e.g. on logout).
  static Future<void> clearData({
    required String baseUrl,
    required String inboxIdentifier,
    String? userIdentifier,
    String? identifierHash,
  }) async {
    await LocalStorage.openDB();
    await LocalStorage.persisted(
      getClientInstanceKey(
        baseUrl: baseUrl,
        inboxIdentifier: inboxIdentifier,
        userIdentifier: userIdentifier,
        identifierHash: identifierHash,
      ),
    ).clear();
  }

  /// Clears all persisted chatwoot data on device.
  static Future<void> clearAllData() => LocalStorage.clearAllPersisted();
}
