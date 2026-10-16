import 'package:dio/dio.dart';

import '../../../core/zukko_chat_client_exception.dart';
import '../../../shared/json_converters.dart';
import '../../../shared/sdk_log.dart';
import '../../models/zukko_chat_config.dart';
import '../../models/zukko_chat_contact.dart';
import '../../models/zukko_chat_user.dart';
import 'zukko_chat_paths.dart';

/// What `POST /config` returned: the contact (with the JWT to use) and the
/// inbox settings.
class ConfigResult {
  const ConfigResult(this.contact, this.config);
  final ZukkoChatContact contact;
  final ZukkoChatConfig config;
}

/// The HTTP calls of the widget session (`/config`, `/contact/set_user`,
/// `/contact`) and the parsing of their answers. Talks through a bare [Dio]
/// (no interceptors): it is the one that establishes the credentials the
/// interceptor attaches. Failures are typed [ZukkoChatException]s; what to do
/// about them is the session's decision.
class WidgetSessionApi {
  WidgetSessionApi(this._dio, this.websiteToken);

  final Dio _dio;
  final String websiteToken;

  Future<Response<Object?>> _send(
    String method,
    String path, {
    String? jwt,
    Object? data,
  }) => _dio.request<Object?>(
    path,
    data: data,
    queryParameters: {ZukkoChatPaths.websiteTokenParam: websiteToken},
    options: Options(
      method: method,
      headers: {ZukkoChatPaths.authTokenHeader: ?jwt},
    ),
  );

  static String _status(DioException e) =>
      '${e.response?.statusCode ?? e.type.name}';

  /// `POST /config`, with [jwt] when the visitor already has a session.
  /// Throws `GET_CONFIG_FAILED`.
  Future<ConfigResult> config({String? jwt}) async {
    try {
      final response = await _send('POST', ZukkoChatPaths.config, jwt: jwt);
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
      final global = body['global_config'];
      return ConfigResult(
        contact,
        ZukkoChatConfig.fromJson(
          channel,
          global is Map<String, dynamic> ? global : null,
        ),
      );
    } on DioException catch (e) {
      sdkLog('config failed: ${e.type.name} ${e.response?.statusCode}');
      throw ZukkoChatException(
        'config failed (${_status(e)})',
        ZukkoChatExceptionType.getConfigFailed,
        error: e.error,
        stackTrace: e.stackTrace,
      );
    } on ZukkoChatException {
      rethrow;
    } catch (e, st) {
      throw ZukkoChatException(
        'invalid config response: ${e.runtimeType}',
        ZukkoChatExceptionType.getConfigFailed,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// `PATCH /contact/set_user` with the session's [jwt]. Returns the new
  /// `widget_auth_token` when the server moved us to another contact. Throws
  /// `INVALID_IDENTIFIER_HASH` (401) or `IDENTIFY_FAILED`.
  Future<String?> setUser(ZukkoChatUser identity, String? jwt) async {
    try {
      final response = await _send(
        'PATCH',
        ZukkoChatPaths.setUser,
        jwt: jwt,
        data: identity.toJson(),
      );
      final body = response.data;
      final token = body is Map ? body['widget_auth_token'] : null;
      return token is String && token.isNotEmpty ? token : null;
    } on DioException catch (e) {
      sdkLog('set_user failed: ${e.type.name} ${e.response?.statusCode}');
      if (e.response?.statusCode == 401) {
        throw ZukkoChatException(
          'the server rejected the identifier hash',
          ZukkoChatExceptionType.invalidIdentifierHash,
        );
      }
      throw ZukkoChatException(
        'set_user failed (${_status(e)})',
        ZukkoChatExceptionType.identifyFailed,
        error: e.error,
        stackTrace: e.stackTrace,
      );
    } catch (e, st) {
      throw ZukkoChatException(
        'set_user failed: ${e.runtimeType}',
        ZukkoChatExceptionType.identifyFailed,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// `GET /contact`: the id of the contact [jwt] belongs to now, or null when
  /// the answer carries none. Throws `IDENTIFY_FAILED` when the check fails.
  Future<int?> currentContactId(String? jwt) async {
    try {
      final response = await _send('GET', ZukkoChatPaths.contact, jwt: jwt);
      final body = response.data;
      return body is Map ? intFromJson(body['id']) : null;
    } catch (e, st) {
      sdkLog('contact check failed: ${e.runtimeType}');
      throw ZukkoChatException(
        'could not verify the contact after set_user: ${e.runtimeType}',
        ZukkoChatExceptionType.identifyFailed,
        error: e is DioException ? e.error : e,
        stackTrace: st,
      );
    }
  }
}
