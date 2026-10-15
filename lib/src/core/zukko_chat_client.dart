import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/local/hive_database.dart';
import '../data/local/instance_key.dart';
import '../data/models/zukko_chat_config.dart';
import '../data/models/zukko_chat_user.dart';
import '../data/remote/api/requests/zukko_chat_new_message_request.dart';
import '../data/remote/api/widget_session.dart';
import '../data/remote/realtime/zukko_chat_action_data.dart';
import '../data/zukko_chat_repository.dart';
import 'zukko_chat_callbacks.dart';
import 'zukko_chat_client_factory.dart';
import 'zukko_chat_upload.dart';

/// Represents a chat client instance on the Zukko Chat Widget API. All chat
/// operations (Example: sendMessage) are passed through the client.
///
/// {@category FlutterClientSdk}
class ZukkoChatClient {
  final ZukkoChatRepository _repository;
  final List<Dio> _dios;
  final WidgetSession? _session;
  bool _disposed = false;

  ZukkoChatClient._(this._repository, this._dios, this._session);

  /// Builds a client around an existing [repository]. Tests only.
  @visibleForTesting
  ZukkoChatClient.withRepository(ZukkoChatRepository repository)
    : _repository = repository,
      _dios = const [],
      _session = null;

  /// Branding and behaviour of the widget inbox (title, colour, working hours,
  /// ...); null until the session was established.
  ZukkoChatConfig? get config => _session?.config;

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
  }) {
    return _repository.sendMessage(
      ZukkoChatNewMessageRequest(
        content: content,
        echoId: echoId,
        replyTo: replyTo,
      ),
      attachments: attachments,
    );
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

  /// Clears this client's conversation and messages. The contact is kept.
  Future<void> clearClientData() => _repository.clear(clearContact: false);

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
    final wiring = await wireZukkoChat(
      baseUrl: baseUrl,
      websiteToken: websiteToken,
      user: user,
      enablePersistence: enablePersistence,
      allowInsecure: allowInsecure,
      callbacks: callbacks,
      socketSubscribeTimeout: socketSubscribeTimeout,
    );
    await wiring.repository.initialize();
    return ZukkoChatClient._(wiring.repository, wiring.dios, wiring.session);
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
  }) => zukkoChatInstanceKey(
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
    await HiveDatabase.openDB();
    await HiveDatabase.clearInstanceFamily(
      getClientInstanceKey(
        baseUrl: baseUrl.trim(),
        websiteToken: websiteToken,
        userIdentifier: userIdentifier,
      ),
    );
  }

  /// Clears all persisted Zukko Chat data on device.
  static Future<void> clearAllData() => HiveDatabase.clearAll();
}
