import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart' as synchronized;

import '../../../core/chatwoot_client_exception.dart';
import '../../local/local_storage.dart';
import '../../models/chatwoot_contact.dart';
import 'chatwoot_client_auth_service.dart';

/// Fills the path placeholders of every request and lazily creates the contact
/// and conversation they need. When the server rejects the session it creates
/// a fresh one once and replays the request once:
///
/// - 401/403 anywhere: the contact is rejected, so contact and conversation are
///   dropped;
/// - 404 on a contact or conversations path: same;
/// - 404 on a messages path: only the conversation is gone, the contact stays.
///
/// Resets are rate limited ([maxResets] per [resetWindow]) so a misbehaving
/// server cannot make the client wipe its data in a loop.
class ChatwootClientApiInterceptor extends Interceptor {
  static const inboxPlaceholder = "{INBOX_IDENTIFIER}";
  static const contactPlaceholder = "{CONTACT_IDENTIFIER}";
  static const conversationPlaceholder = "{CONVERSATION_IDENTIFIER}";

  static const _templateKey = 'chatwoot_template';
  static const _generationKey = 'chatwoot_generation';
  static const _retriedKey = 'retried';
  static const _recoverableStatuses = {401, 403, 404};

  final String _inboxIdentifier;
  final LocalStorage _localStorage;
  final ChatwootClientAuthService _authService;

  /// One lock for bootstrap and recovery, so they never see each other's
  /// half-written session.
  final _lock = synchronized.Lock();

  /// Called after a reset created a new session (the realtime token changed).
  final void Function()? onSessionReset;
  final DateTime Function() _now;
  final _resetTimes = <DateTime>[];
  static const maxResets = 3;
  static const resetWindow = Duration(minutes: 1);
  static const _maxSourceIdLength = 256;

  /// Bumped on every session reset. A request that failed under an older
  /// generation was already covered by a reset: it only replays.
  int _generation = 0;

  ChatwootClientApiInterceptor(
    this._inboxIdentifier,
    this._localStorage,
    this._authService, {
    this.onSessionReset,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The contact's source id is needed for every REST path; the server should
  /// always send it, but a missing one must surface as a typed error.
  static String _sourceId(ChatwootContact contact) {
    final id = contact.contactIdentifier;
    // the id ends up in a URL path: bound it and refuse dot segments
    if (id == null ||
        id.isEmpty ||
        id.length > _maxSourceIdLength ||
        id == '.' ||
        id == '..') {
      throw ChatwootClientException(
        "contact has no usable source_id",
        ChatwootClientExceptionType.CREATE_CONTACT_FAILED,
      );
    }
    return id;
  }

  String _resolve(String path, String contactIdentifier, int conversationId) =>
      path
          .replaceAll(inboxPlaceholder, Uri.encodeComponent(_inboxIdentifier))
          .replaceAll(
            contactPlaceholder,
            Uri.encodeComponent(contactIdentifier),
          )
          .replaceAll(conversationPlaceholder, "$conversationId");

  /// Returns the stored session, creating the missing contact / conversation.
  /// Callers hold [_lock].
  Future<({String sourceId, int conversationId})> _ensureSession() async {
    var contact = _localStorage.contact.get();
    var conversation = _localStorage.conversation.get();
    if (contact == null) {
      contact = await _authService.createNewContact(
        _inboxIdentifier,
        _localStorage.user.get(),
      );
      await _localStorage.contact.save(contact);
      conversation = null; // belonged to the previous contact
    }
    final sourceId = _sourceId(contact);
    if (conversation == null) {
      conversation = await _authService.createNewConversation(
        _inboxIdentifier,
        sourceId,
      );
      await _localStorage.conversation.save(conversation);
    }
    return (sourceId: sourceId, conversationId: conversation.id);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      await _lock.synchronized(() async {
        final session = await _ensureSession();
        options.extra[_templateKey] = options.path;
        options.extra[_generationKey] = _generation;
        options.path = _resolve(
          options.path,
          session.sourceId,
          session.conversationId,
        );
      });
      handler.next(options);
    } on ChatwootClientException catch (e) {
      handler.reject(
        DioException(requestOptions: options, error: e, message: e.cause),
      );
    }
  }

  /// Dio delivers 4xx responses here. See the class docs for what is reset.
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final template = options.extra[_templateKey];
    final status = err.response?.statusCode;
    if (!_recoverableStatuses.contains(status) ||
        template is! String ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    // 401/403 reject the contact; a 404 only does so off the messages path
    final resetContact =
        status != 404 || !template.contains(conversationPlaceholder);

    try {
      var reset = false;
      final session = await _lock.synchronized(() async {
        if (options.extra[_generationKey] == _generation) {
          if (!_resetAllowed()) return null;
          reset = true;
          _generation++;
          await _localStorage.clear(clearChatwootUserStorage: false);
          if (resetContact) await _localStorage.contact.delete();
        }
        return _ensureSession();
      });
      if (session == null) return handler.next(err);
      if (reset) onSessionReset?.call();

      final retry = options.copyWith(
        path: _resolve(template, session.sourceId, session.conversationId),
        extra: {...options.extra, _retriedKey: true},
      );
      // ponytail: replays through the auth Dio (no interceptors, so no loop);
      // revisit if requests ever need per-request auth headers added here.
      handler.resolve(await _authService.dio.fetch(retry));
    } on ChatwootClientException catch (e) {
      handler.reject(
        DioException(requestOptions: options, error: e, message: e.cause),
      );
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  bool _resetAllowed() {
    final now = _now();
    _resetTimes.removeWhere((t) => now.difference(t) > resetWindow);
    if (_resetTimes.length >= maxResets) return false;
    _resetTimes.add(now);
    return true;
  }
}
