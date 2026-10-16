import 'package:synchronized/synchronized.dart';

import '../../../core/zukko_chat_client_exception.dart';
import '../../../shared/backoff.dart';
import '../../../shared/rate_budget.dart';
import '../../../shared/safe_invoke.dart';
import '../../../shared/sdk_log.dart';
import '../../local/local_storage.dart';
import '../../models/zukko_chat_config.dart';
import '../../models/zukko_chat_user.dart';
import 'widget_session_api.dart';

/// Why a session is being rebuilt.
enum SessionRefreshReason {
  /// The server no longer knows the JWT: drop it and start as a new visitor.
  staleToken,

  /// The realtime subscription was rejected: re-read the pubsub token.
  socketRejected,
}

/// What the session tells its owner (the repository registers itself here).
class SessionListener {
  const SessionListener({this.onReset, this.onReady, this.onError});

  /// A rebuild replaced the contact or the pubsub token (also a first start
  /// that found another contact than the stored one).
  final void Function()? onReset;

  /// [WidgetSession.start] succeeded (the session became usable).
  final void Function()? onReady;

  /// Non-fatal problems (`IDENTIFY_FAILED` for a user without an identifier).
  final void Function(ZukkoChatException)? onError;
}

/// The one developer-facing text for a rejected identifier hash (401 on
/// `set_user`): [hashSent] tells "missing" from "wrong". Append a
/// documentation link here when there is one.
String identityValidationMessage({required bool hashSent}) =>
    'Identity validation is enabled for this inbox, but identifierHash is '
    '${hashSent ? 'wrong' : 'missing'} for user.identifier. Compute '
    'HMAC-SHA256(<inbox HMAC token>, identifier) on your backend and pass it '
    'as ZukkoChatUser.identifierHash.';

/// The widget session: JWT + contact + pubsub token.
///
/// `start` runs `POST /config` (with the saved JWT, if any) then, for an
/// identified user, `PATCH /contact/set_user` and, when the server answers
/// with a new `widget_auth_token`, `POST /config` once more. All entry points
/// share one lock, so concurrent failures coalesce into one rebuild, and
/// rebuilds are rate limited so a broken server cannot cause a loop. The HTTP
/// calls live in [WidgetSessionApi].
class WidgetSession {
  WidgetSession({
    required this._api,
    required this._storage,
    this.user,
    this.listener = const SessionListener(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _budget = RateBudget(max: maxRefreshes, window: refreshWindow, now: now);

  static const maxRefreshes = 3;
  static const refreshWindow = Duration(seconds: 60);

  /// Backstop for one whole rebuild; the Dio timeouts normally fire first.
  static const stepTimeout = Duration(seconds: 90);

  /// A failed [start] is not retried for `2^failures` seconds (at most this).
  static const maxStartBackoff = Duration(seconds: 60);
  static const _maxStartFailures = 6;

  final ZukkoChatUser? user;

  /// Who is told about resets, readiness and warnings. Set by the owner.
  SessionListener listener;

  final WidgetSessionApi _api;
  final LocalStorage _storage;
  final DateTime Function() _now;
  final RateBudget _budget;
  final _lock = Lock();

  bool _ready = false;
  ZukkoChatException? _failure;
  ZukkoChatException? _lastStartError;
  DateTime? _nextStartAt;
  int _startFailures = 0;
  ZukkoChatConfig? _config;
  int _generation = 0;

  /// The inbox's websiteToken; sent with every request.
  String get websiteToken => _api.websiteToken;

  /// Branding from the last successful `/config`; null until then.
  ZukkoChatConfig? get config => _config;

  /// Bumped whenever the credentials were replaced. A request that failed
  /// under an older generation was already covered by a rebuild.
  int get generation => _generation;

  /// The JWT for `X-Auth-Token`, or null before the first `/config`.
  String? get authToken => _storage.contact.get()?.authToken;

  /// True once [start] succeeded.
  bool get isReady => _ready;

  /// Set once the server rejected the user's identifier hash. Terminal.
  ZukkoChatException? get failure => _failure;

  /// Completes when the session is usable; throws the typed failure otherwise.
  Future<void> ensureReady() async {
    final failed = _failure;
    if (failed != null) throw failed;
    if (!_ready) await start();
  }

  /// Establishes the session. Throws [ZukkoChatException]
  /// (`GET_CONFIG_FAILED`, `IDENTIFY_FAILED`, `INVALID_IDENTIFIER_HASH`). A
  /// failed start can be retried by calling it again (after a growing pause:
  /// calls inside it rethrow the last error without a request), except an
  /// identifier hash rejection. An identified user is never made ready
  /// without a successful `set_user`.
  Future<void> start() => _lock.synchronized(() async {
    final failed = _failure;
    if (failed != null) throw failed;
    if (_ready) return;
    final retryAt = _nextStartAt;
    final lastError = _lastStartError;
    if (retryAt != null && lastError != null && _now().isBefore(retryAt)) {
      throw lastError;
    }
    try {
      await _guard(() => _establish(useSavedToken: true));
      _ready = true;
      _startFailures = 0;
      _nextStartAt = _lastStartError = null;
    } on ZukkoChatException catch (e) {
      if (e.type != ZukkoChatExceptionType.invalidIdentifierHash) {
        _lastStartError = e;
        if (_startFailures < _maxStartFailures) _startFailures++;
        _nextStartAt = _now().add(
          exponentialBackoff(
            attempt: _startFailures,
            base: const Duration(seconds: 1),
            max: maxStartBackoff,
          ),
        );
      }
      rethrow;
    }
    _notify(listener.onReady);
  });

  /// Rebuilds the session. Returns whether the contact or pubsub token changed.
  /// Throws `SESSION_EXPIRED` when rebuilt too often.
  Future<bool> refresh(SessionRefreshReason reason) =>
      _lock.synchronized(() async {
        final failed = _failure;
        if (failed != null) throw failed;
        _ensureBudget();
        _budget.spend();
        final changed = await _guard(
          () => _establish(
            useSavedToken: reason != SessionRefreshReason.staleToken,
          ),
        );
        _ready = true;
        return changed;
      });

  /// A request that ran under [requestGeneration] got a 404, which is also what
  /// the server answers for an unknown JWT. Asks `/config` with the current
  /// JWT: the same contact means the token is fine (returns `false`, the 404
  /// is genuine); another contact means the token was stale, the new session is
  /// adopted (returns `true`, replay the request).
  Future<bool> recoverFrom404(
    int requestGeneration,
  ) => _lock.synchronized(() async {
    if (requestGeneration != _generation) return true; // already rebuilt
    final failed = _failure;
    if (failed != null) throw failed;
    _ensureBudget();
    final previous = _storage.contact.get();
    final ConfigResult probe;
    try {
      probe = await _guard(() => _api.config(jwt: authToken));
    } catch (_) {
      _budget.spend(); // a failing probe counts, so a broken server cannot loop
      rethrow;
    }
    // the same contact: a genuine 404, not a rebuild, so it costs nothing
    if (previous != null && probe.contact.id == previous.id) return false;
    _budget.spend();
    await _guard(() => _establish(useSavedToken: true, first: probe));
    return true;
  });

  // ---- steps (callers hold the lock) ----

  Future<T> _guard<T>(Future<T> Function() step) async {
    try {
      return await step().timeout(stepTimeout);
    } on ZukkoChatException {
      rethrow;
    } catch (e, st) {
      throw ZukkoChatException(
        'session setup failed: ${e.runtimeType}',
        ZukkoChatExceptionType.getConfigFailed,
        error: e,
        stackTrace: st,
      );
    }
  }

  void _ensureBudget() {
    if (_budget.hasRoom) return;
    throw ZukkoChatException(
      'the session was rebuilt $maxRefreshes times within a minute',
      ZukkoChatExceptionType.sessionExpired,
    );
  }

  /// The one place that announces "the session was replaced": bumps
  /// [generation] and tells the listener.
  void _markReplaced() {
    _generation++;
    _notify(listener.onReset);
  }

  /// config -> (set_user -> config). Returns whether contact or pubsub token
  /// differ from what was stored before, and announces a replacement of a
  /// stored session (also when a later step fails after the stored contact was
  /// already swapped).
  Future<bool> _establish({
    required bool useSavedToken,
    ConfigResult? first,
  }) async {
    final before = _storage.contact.get();
    var completed = false;
    try {
      await _adopt(
        first ?? await _api.config(jwt: useSavedToken ? authToken : null),
      );
      final identity = user;
      if (identity != null && identity.toJson().isNotEmpty) {
        await _identifyAndAdopt(identity);
      }
      completed = true;
    } finally {
      final after = _storage.contact.get();
      final idChanged =
          before != null && after != null && before.id != after.id;
      final tokenChanged =
          completed &&
          before != null &&
          after != null &&
          before.pubsubToken != after.pubsubToken;
      if (idChanged || tokenChanged) _markReplaced();
    }
    final after = _storage.contact.get();
    return before?.id != after?.id || before?.pubsubToken != after?.pubsubToken;
  }

  /// `set_user`, then whatever it requires to end up with the right contact.
  Future<void> _identifyAndAdopt(ZukkoChatUser identity) async {
    final strict = identity.identifier?.isNotEmpty ?? false;
    final String? newToken;
    try {
      newToken = await _api.setUser(identity, authToken);
    } on ZukkoChatException catch (e) {
      if (e.type == ZukkoChatExceptionType.invalidIdentifierHash) {
        sdkLog(
          identityValidationMessage(
            hashSent: identity.identifierHash?.isNotEmpty ?? false,
          ),
          level: SdkLogLevel.error,
        );
        _failure = e; // fail closed: never fall back to an anonymous session
        rethrow;
      }
      // a user with an identifier is never made ready without set_user
      if (strict) rethrow;
      _notifyError(listener.onError, e);
      return;
    }
    if (newToken != null) {
      // another contact now: its pubsub token needs a second /config, which
      // also hands out the JWT to store
      await _adopt(await _api.config(jwt: newToken));
    } else if (!await _sameContact(strict)) {
      // set_user may have merged us into another contact behind the same JWT:
      // ask /config once more for the contact and pubsub token it has
      await _adopt(await _api.config(jwt: authToken));
    }
    await _mirror(identity);
  }

  /// Whether the JWT still belongs to the stored contact. When the check
  /// itself fails: [strict] (identified user) throws `IDENTIFY_FAILED` instead
  /// of guessing, otherwise it assumes yes.
  Future<bool> _sameContact(bool strict) async {
    try {
      final id = await _api.currentContactId(authToken);
      return id == null || id == _storage.contact.get()?.id;
    } on ZukkoChatException {
      if (strict) rethrow;
      return true;
    }
  }

  /// Stores the contact; a different contact than before takes the old
  /// conversation and messages with it.
  Future<void> _adopt(ConfigResult result) async {
    final previous = _storage.contact.get();
    if (previous != null && previous.id != result.contact.id) {
      await _storage.clear(clearContact: false);
    }
    await _storage.contact.save(result.contact);
    _config = result.config;
  }

  /// Keeps the stored contact in line with what `set_user` just wrote.
  Future<void> _mirror(ZukkoChatUser identity) async {
    final stored = _storage.contact.get();
    if (stored == null) return;
    await _storage.contact.save(
      stored.copyWith(
        contactIdentifier: identity.identifier,
        name: identity.name,
        email: identity.email,
        phoneNumber: identity.phoneNumber,
      ),
    );
  }

  void _notify(void Function()? callback) {
    if (callback != null) safeInvoke(callback, 'session');
  }

  void _notifyError(
    void Function(ZukkoChatException)? callback,
    ZukkoChatException e,
  ) {
    if (callback != null) safeInvoke(() => callback(e), 'onError');
  }
}
