import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart';

import '../../../core/chatwoot_client_exception.dart';
import '../../../shared/sdk_log.dart';
import '../../local/local_storage.dart';
import '../../models/chatwoot_contact.dart';
import '../../models/chatwoot_user.dart';
import 'chatwoot_paths.dart';
import 'widget_config.dart';

/// Why a session is being rebuilt.
enum SessionRefreshReason {
  /// The server no longer knows the JWT: drop it and start as a new visitor.
  staleToken,

  /// The realtime subscription was rejected: re-read the pubsub token.
  socketRejected,

  /// The app asked for it.
  manual,
}

/// The widget session: JWT + contact + pubsub token.
///
/// `start` runs `POST /config` (with the saved JWT, if any) then, for an
/// identified user, `PATCH /contact/set_user` and, when the server answers
/// with a new `widget_auth_token`, `POST /config` once more. All entry points
/// share one lock, so concurrent failures coalesce into one rebuild, and
/// rebuilds are rate limited so a broken server cannot cause a loop.
///
/// It talks through a bare [Dio] (no interceptors): it is the one that
/// establishes the credentials the interceptor attaches.
class WidgetSession {
  WidgetSession({
    required this._dio,
    required this.websiteToken,
    required this._storage,
    this.user,
    this.onSessionReset,
    this.onReady,
    this.onError,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const maxRefreshes = 3;
  static const refreshWindow = Duration(seconds: 60);

  /// Backstop for one whole rebuild; the Dio timeouts normally fire first.
  static const stepTimeout = Duration(seconds: 90);

  /// A failed [start] is not retried for `2^failures` seconds (at most this).
  static const maxStartBackoff = Duration(seconds: 60);

  final String websiteToken;
  final ZukkoChatUser? user;

  /// Called after a rebuild changed the contact or the pubsub token (also by
  /// a first start that found another contact than the stored one).
  final void Function()? onSessionReset;

  /// Called each time [start] succeeded (the session became usable).
  final void Function()? onReady;

  /// Receives non-fatal problems (`IDENTITY_NOT_VERIFIED`, and `IDENTIFY_FAILED`
  /// for a user without an identifier).
  final void Function(ZukkoChatException)? onError;

  final Dio _dio;
  final LocalStorage _storage;
  final DateTime Function() _now;
  final _lock = Lock();
  final _refreshTimes = <DateTime>[];

  bool _ready = false;
  bool _warnedUnverified = false;
  ZukkoChatException? _failure;
  ZukkoChatException? _lastStartError;
  DateTime? _nextStartAt;
  int _startFailures = 0;

  /// Branding from the last successful `/config`; null until then.
  WidgetConfig? config;

  /// Bumped whenever the credentials were replaced. A request that failed
  /// under an older generation was already covered by a rebuild.
  int generation = 0;

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
    if (retryAt != null && _now().isBefore(retryAt)) throw _lastStartError!;
    final hadContact = _storage.contact.get() != null;
    try {
      final changed = await _guard(() => _establish(useSavedToken: true));
      _ready = true;
      _startFailures = 0;
      _nextStartAt = _lastStartError = null;
      if (changed && hadContact) {
        generation++;
        _fire(onSessionReset);
      }
    } on ZukkoChatException catch (e) {
      if (e.type != ZukkoChatExceptionType.INVALID_IDENTIFIER_HASH) {
        _lastStartError = e;
        final seconds = 1 << (_startFailures < 6 ? ++_startFailures : 6);
        _nextStartAt = _now().add(
          Duration(
            seconds: seconds < maxStartBackoff.inSeconds
                ? seconds
                : maxStartBackoff.inSeconds,
          ),
        );
      }
      rethrow;
    }
    _fire(onReady);
  });

  /// Rebuilds the session. Returns whether the contact or pubsub token changed.
  /// Throws `SESSION_EXPIRED` when rebuilt too often.
  Future<bool> refresh(SessionRefreshReason reason) =>
      _lock.synchronized(() async {
        final failed = _failure;
        if (failed != null) throw failed;
        _ensureBudget();
        _spend();
        final changed = await _guard(
          () => _establish(
            useSavedToken: reason != SessionRefreshReason.staleToken,
          ),
        );
        _ready = true;
        generation++;
        if (changed) _fire(onSessionReset);
        return changed;
      });

  /// A request that ran under [requestGeneration] got a 404, which is also what
  /// the server answers for an unknown JWT. Asks `/config` with the current
  /// JWT: the same contact means the token is fine (returns `false`, the 404
  /// is genuine); another contact means the token was stale, the new session is
  /// adopted (returns `true`, replay the request).
  Future<bool> recoverFrom404(int requestGeneration) =>
      _lock.synchronized(() async {
        if (requestGeneration != generation) return true; // already rebuilt
        final failed = _failure;
        if (failed != null) throw failed;
        _ensureBudget();
        final previous = _storage.contact.get();
        final _ConfigResult probe;
        try {
          probe = await _guard(() => _config(useSavedToken: true));
        } catch (_) {
          _spend(); // a failing probe counts, so a broken server cannot loop
          rethrow;
        }
        // the same contact: a genuine 404, not a rebuild, so it costs nothing
        if (previous != null && probe.contact.id == previous.id) return false;
        _spend();
        await _guard(() => _establish(useSavedToken: true, first: probe));
        generation++;
        _fire(onSessionReset);
        return true;
      });

  // ---- steps (callers hold the lock) ----

  Future<T> _guard<T>(Future<T> Function() step) async {
    try {
      return await step().timeout(stepTimeout);
    } on ZukkoChatException {
      rethrow;
    } catch (e) {
      throw ZukkoChatException(
        'session setup failed: ${e.runtimeType}',
        ZukkoChatExceptionType.GET_CONFIG_FAILED,
      );
    }
  }

  void _ensureBudget() {
    final now = _now();
    _refreshTimes.removeWhere((t) => now.difference(t) >= refreshWindow);
    if (_refreshTimes.length >= maxRefreshes) {
      throw ZukkoChatException(
        'the session was rebuilt $maxRefreshes times within a minute',
        ZukkoChatExceptionType.SESSION_EXPIRED,
      );
    }
  }

  void _spend() => _refreshTimes.add(_now());

  /// config -> (set_user -> config). Returns whether contact or pubsub token
  /// differ from what was stored before. When a step fails after the stored
  /// contact was already replaced, the rebuild still counts as a reset.
  Future<bool> _establish({
    required bool useSavedToken,
    _ConfigResult? first,
  }) async {
    final before = _storage.contact.get();
    var done = false;
    try {
      await _adopt(first ?? await _config(useSavedToken: useSavedToken));

      final identity = user;
      if (identity != null && identity.toJson().isNotEmpty) {
        final strict = _isIdentified(identity);
        final (identified, newToken) = await _identify(identity, strict);
        if (newToken != null) {
          // another contact now: its pubsub token needs a second /config,
          // which also hands out the JWT to store
          await _adopt(await _config(jwt: newToken));
        } else if (identified && !await _sameContact(strict)) {
          // set_user may have merged us into another contact behind the same
          // JWT: ask /config once more for the contact and pubsub token it has
          await _adopt(await _config(useSavedToken: true));
        }
        if (identified) await _mirror(identity);
      }
      done = true;
    } finally {
      final after = _storage.contact.get();
      if (!done && before != null && after != null && before.id != after.id) {
        generation++;
        _fire(onSessionReset);
      }
    }
    final after = _storage.contact.get();
    return before?.id != after?.id || before?.pubsubToken != after?.pubsubToken;
  }

  static bool _isIdentified(ZukkoChatUser u) =>
      u.identifier?.isNotEmpty ?? false;

  Future<_ConfigResult> _config({
    bool useSavedToken = true,
    String? jwt,
  }) async {
    jwt ??= useSavedToken ? authToken : null;
    try {
      final response = await _dio.post<Object?>(
        ChatwootPaths.config,
        queryParameters: {'website_token': websiteToken},
        options: Options(headers: {'X-Auth-Token': ?jwt}),
      );
      final body = response.data as Map<String, dynamic>;
      final channel = body['website_channel_config'] as Map<String, dynamic>;
      final token = channel['auth_token'];
      if (token is! String || token.isEmpty) {
        throw const FormatException('no auth_token');
      }
      final contact = ZukkoChatContact.fromJson(
        body['contact'] as Map<String, dynamic>,
      ).copyWith(authToken: token);
      if (contact.id <= 0) throw const FormatException('no contact id');
      return _ConfigResult(
        contact,
        WidgetConfig.fromJson(
          channel,
          body['global_config'] is Map<String, dynamic>
              ? body['global_config'] as Map<String, dynamic>
              : null,
        ),
      );
    } on DioException catch (e) {
      sdkLog('config failed: ${e.type.name} ${e.response?.statusCode}');
      throw ZukkoChatException(
        'config failed (${e.response?.statusCode ?? e.type.name})',
        ZukkoChatExceptionType.GET_CONFIG_FAILED,
      );
    } on ZukkoChatException {
      rethrow;
    } catch (e) {
      throw ZukkoChatException(
        'invalid config response: ${e.runtimeType}',
        ZukkoChatExceptionType.GET_CONFIG_FAILED,
      );
    }
  }

  /// Stores the contact; a different contact than before takes the old
  /// conversation and messages with it.
  Future<void> _adopt(_ConfigResult result) async {
    final previous = _storage.contact.get();
    if (previous != null && previous.id != result.contact.id) {
      await _storage.clear(clearChatwootUserStorage: false);
    }
    await _storage.contact.save(result.contact);
    config = result.config;
  }

  /// Runs `set_user`. Returns whether it succeeded and the new
  /// `widget_auth_token` if the server moved us to another contact. A rejected
  /// hash is fatal. Any other failure is fatal-but-retryable (`IDENTIFY_FAILED`)
  /// for a user with an identifier ([strict]: never fall back to an anonymous
  /// session), and only reported for a user without one.
  Future<(bool, String?)> _identify(ZukkoChatUser identity, bool strict) async {
    if (strict && (identity.identifierHash?.isEmpty ?? true)) _warnUnverified();
    ZukkoChatException error;
    try {
      final response = await _dio.patch<Object?>(
        ChatwootPaths.setUser,
        queryParameters: {'website_token': websiteToken},
        options: Options(headers: {'X-Auth-Token': authToken}),
        data: identity.toJson(),
      );
      final body = response.data;
      final token = body is Map ? body['widget_auth_token'] : null;
      return (true, token is String && token.isNotEmpty ? token : null);
    } on DioException catch (e) {
      sdkLog('set_user failed: ${e.type.name} ${e.response?.statusCode}');
      if (e.response?.statusCode == 401) {
        // fail closed: never fall back to an anonymous session
        throw _failure = ZukkoChatException(
          'the server rejected the identifier hash',
          ZukkoChatExceptionType.INVALID_IDENTIFIER_HASH,
        );
      }
      error = ZukkoChatException(
        'set_user failed (${e.response?.statusCode ?? e.type.name})',
        ZukkoChatExceptionType.IDENTIFY_FAILED,
      );
    } catch (e) {
      error = ZukkoChatException(
        'set_user failed: ${e.runtimeType}',
        ZukkoChatExceptionType.IDENTIFY_FAILED,
      );
    }
    if (strict) throw error;
    _report(error);
    return (false, null);
  }

  /// An identifier without a hash only works while the inbox does not enforce
  /// identity validation, which lets anyone claim any identifier.
  void _warnUnverified() {
    if (_warnedUnverified) return;
    _warnedUnverified = true;
    _report(
      ZukkoChatException(
        'user.identifier is set without identifierHash: the identity is not verified',
        ZukkoChatExceptionType.IDENTITY_NOT_VERIFIED,
      ),
    );
  }

  /// `GET /contact` names the contact the JWT belongs to now; true when it is
  /// the one stored. When the check itself fails: [strict] (identified user)
  /// throws `IDENTIFY_FAILED` instead of guessing, otherwise it assumes yes.
  Future<bool> _sameContact(bool strict) async {
    try {
      final response = await _dio.get<Object?>(
        ChatwootPaths.contact,
        queryParameters: {'website_token': websiteToken},
        options: Options(headers: {'X-Auth-Token': authToken}),
      );
      final body = response.data;
      final id = body is Map ? body['id'] : null;
      return id is! int || id == _storage.contact.get()?.id;
    } catch (e) {
      sdkLog('contact check failed: ${e.runtimeType}');
      if (strict) {
        throw ZukkoChatException(
          'could not verify the contact after set_user: ${e.runtimeType}',
          ZukkoChatExceptionType.IDENTIFY_FAILED,
        );
      }
      return true;
    }
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

  void _fire(void Function()? callback) {
    try {
      callback?.call();
    } catch (e) {
      sdkLog('session callback threw: ${e.runtimeType}');
    }
  }

  void _report(ZukkoChatException error) {
    try {
      onError?.call(error);
    } catch (e) {
      sdkLog('onError callback threw: ${e.runtimeType}');
    }
  }
}

class _ConfigResult {
  const _ConfigResult(this.contact, this.config);
  final ZukkoChatContact contact;
  final WidgetConfig config;
}
