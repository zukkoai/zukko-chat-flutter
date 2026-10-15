import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/chatwoot_repository.dart';
import '../data/local/instance_key.dart';
import '../data/local/local_storage.dart';
import '../data/models/chatwoot_user.dart';
import '../data/remote/api/chatwoot_client_service.dart';
import '../data/remote/api/requests/chatwoot_new_message_request.dart';
import '../data/remote/api/widget_auth_interceptor.dart';
import '../data/remote/api/widget_config.dart';
import '../data/remote/api/widget_session.dart';
import '../data/remote/realtime/chatwoot_action_data.dart';
import '../data/remote/realtime/chatwoot_socket.dart';
import '../shared/http_client.dart';
import '../shared/sdk_log.dart';
import '../shared/url_policy.dart';
import 'chatwoot_callbacks.dart';
import 'chatwoot_client_exception.dart';
import 'chatwoot_upload.dart';

/// Represents a chat client instance on the Zukko Chat Widget API. All chat
/// operations (Example: sendMessage) are passed through the client.
///
/// {@category FlutterClientSdk}
class ZukkoChatClient {
  final ChatwootRepository _repository;
  final List<Dio> _dios;
  final WidgetSession? _session;
  bool _disposed = false;

  final String baseUrl;
  final String websiteToken;
  final ZukkoChatCallbacks? callbacks;
  final ZukkoChatUser? user;

  ZukkoChatClient._(
    this._repository,
    this._dios,
    this._session, {
    required this.baseUrl,
    required this.websiteToken,
    this.user,
    this.callbacks,
  });

  /// Builds a client around an existing [repository]. Tests only.
  @visibleForTesting
  ZukkoChatClient.withRepository(
    ChatwootRepository repository, {
    required this.baseUrl,
    required this.websiteToken,
    this.user,
    this.callbacks,
  }) : _repository = repository,
       _dios = const [],
       _session = null;

  /// Branding and behaviour of the widget inbox (title, colour, working hours,
  /// ...); null until the session was established.
  WidgetConfig? get config => _session?.config;

  /// Retrieves Zukko Chat client's messages. If persistence is enabled
  /// [ZukkoChatCallbacks.onPersistedMessagesRetrieved] will be triggered with
  /// persisted messages. On successfully fetch from remote server
  /// [ZukkoChatCallbacks.onMessagesRetrieved] will be triggered. Completes once
  /// the remote fetch finished.
  Future<void> loadMessages() async {
    _repository.getPersistedMessages();
    await _repository.getMessages();
  }

  /// Sends Zukko Chat message. The echoId is your temporary message id. When message sends successfully
  /// [ZukkoChatMessage] will be returned with the [echoId] on [ZukkoChatCallbacks.onMessageSent]. If
  /// message fails to send [ZukkoChatCallbacks.onError] will be triggered [echoId] as data.
  ///
  /// [attachments] (images, files, voice; at most [ZukkoChatUpload.maxSize]
  /// each) go with the message; [content] may then be empty. [replyTo] is the
  /// id of the message this one answers.
  Future<void> sendMessage({
    required String content,
    required String echoId,
    List<ZukkoChatUpload> attachments = const [],
    int? replyTo,
  }) async {
    final request = ChatwootNewMessageRequest(
      content: content,
      echoId: echoId,
      replyTo: replyTo,
    );
    await _repository.sendMessage(request, attachments: attachments);
  }

  /// Tells the agents the user started ([on]) or stopped typing. Best effort:
  /// failures are not reported.
  Future<void> setTyping(bool on) => _repository.setTyping(on);

  /// Tells the agents the user has read their messages. Best effort.
  Future<void> markSeen() => _repository.markSeen();

  /// Call when the app returns to the foreground: restarts the realtime
  /// connection if it had stopped (for instance after a rejected subscription).
  void resume() => _repository.resume();

  /// Sends the realtime presence action (`update_presence`).
  ///
  /// Completes with `false` when the action could not be sent (the realtime
  /// connection is not subscribed).
  Future<bool> sendAction(ZukkoChatActionType action) async =>
      _repository.sendAction(action);

  /// Disposes Zukko Chat client: cancels stream subscriptions and timers and
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

  /// Creates an instance of [ZukkoChatClient] with the [baseUrl] of your Zukko Chat installation,
  /// [websiteToken] of the web widget inbox. Specify custom user details using [user] and [callbacks] for
  /// handling Zukko Chat events. By default persistence is enabled, to disable persistence set [enablePersistence] as false.
  ///
  /// [baseUrl] must be https; plain http is only accepted for localhost /
  /// 10.0.2.2, or for any host when [allowInsecure] is true (development only).
  /// An invalid [baseUrl] throws an [ArgumentError].
  ///
  /// Completes once the session (`/config`, `set_user`) and the conversation
  /// refresh finished. A rejected `identifierHash` fails closed: the client
  /// reports `INVALID_IDENTIFIER_HASH` and neither fetches nor connects.
  /// Failures during that refresh are reported through [ZukkoChatCallbacks.onError]
  /// instead of being thrown. If local storage cannot be opened the client
  /// still works, without persistence, and reports `STORAGE_FAILED`.
  ///
  /// Each client owns its storage: clients without persistence never share state,
  /// persisted clients with the same [getClientInstanceKey] share the persisted
  /// contact, conversation and messages. Persisted data is encrypted at rest;
  /// the user's `identifierHash` and `customAttributes` are never written to disk.
  static Future<ZukkoChatClient> create({
    required String baseUrl,
    required String websiteToken,
    ZukkoChatUser? user,
    bool enablePersistence = true,
    bool allowInsecure = false,
    ZukkoChatCallbacks? callbacks,
    @visibleForTesting Duration? socketSubscribeTimeout,
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
            websiteToken: websiteToken,
            userIdentifier: user?.identifier,
            identifierHash: user?.identifierHash,
          ),
        );
      } catch (e) {
        sdkLog('persistence unavailable: $e');
        callbacks?.onError?.call(
          e is ZukkoChatException
              ? e
              : ZukkoChatException(
                  'local storage unavailable, continuing without persistence: $e',
                  ZukkoChatExceptionType.STORAGE_FAILED,
                ),
        );
      }
    }

    late final ChatwootRepositoryImpl repository;
    final bareDio = chatwootDio(baseUrl);
    final session = WidgetSession(
      dio: bareDio,
      websiteToken: websiteToken,
      storage: storage,
      user: user,
      onSessionReset: () => repository.onSessionReset(),
      onReady: () => repository.onSessionReady(),
      onError: (e) => repository.reportError(e),
    );
    final dio = chatwootDio(baseUrl);
    dio.interceptors.add(
      WidgetAuthInterceptor(
        session: session,
        websiteToken: websiteToken,
        dio: dio,
      ),
    );

    repository = ChatwootRepositoryImpl(
      clientService: ChatwootClientServiceImpl(dio: dio),
      socket: ChatwootSocket(
        url: cableUrl,
        tokenProvider: () => storage.contact.get()?.pubsubToken,
        subscribeTimeout:
            socketSubscribeTimeout ?? const Duration(seconds: 10),
      ),
      localStorage: storage,
      streamCallbacks: callbacks ?? ZukkoChatCallbacks(),
      session: session,
    );

    final client = ZukkoChatClient._(
      repository,
      [bareDio, dio],
      session,
      baseUrl: baseUrl,
      websiteToken: websiteToken,
      user: user,
      callbacks: callbacks,
    );

    await repository.initialize(user);
    return client;
  }

  /// Creates a Zukko Chat client instance key using the Zukko Chat client instance baseurl, websiteToken
  /// and userIdentifier. Client instance keys are used to differentiate between client instances and their data
  /// (contact, conversation and messages).
  ///
  /// Separate persisted [ZukkoChatClient] instances with same baseUrl, websiteToken and userIdentifier
  /// are regarded as the same and therefore use the same contact and conversation.
  /// The same identifier with a different [identifierHash] is a different instance.
  static String getClientInstanceKey({
    required String baseUrl,
    required String websiteToken,
    String? userIdentifier,
    String? identifierHash,
  }) => chatwootInstanceKey(
    baseUrl: baseUrl,
    websiteToken: websiteToken,
    userIdentifier: userIdentifier,
    identifierHash: identifierHash,
  );

  /// Clears all persisted Zukko Chat data on device for a particular Zukko Chat client instance.
  /// See [getClientInstanceKey] on how Zukko Chat client instances are differentiated.
  /// Records stored under the same [baseUrl], [websiteToken] and [userIdentifier]
  /// with ANY identifier hash are removed too (a rotated hash leaves no orphan);
  /// [identifierHash] is not needed. Other users and other inboxes are untouched.
  /// Use [clearAllData] to wipe everything.
  /// Can be called before any client was created (e.g. on logout).
  static Future<void> clearData({
    required String baseUrl,
    required String websiteToken,
    String? userIdentifier,
    String? identifierHash,
  }) async {
    await LocalStorage.openDB();
    await LocalStorage.clearInstanceFamily(
      getClientInstanceKey(
        baseUrl: baseUrl,
        websiteToken: websiteToken,
        userIdentifier: userIdentifier,
      ),
    );
  }

  /// Clears all persisted Zukko Chat data on device.
  static Future<void> clearAllData() => LocalStorage.clearAllPersisted();
}
