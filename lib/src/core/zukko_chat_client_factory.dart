import 'package:dio/dio.dart';

import '../data/local/instance_key.dart';
import '../data/local/open_storage.dart';
import '../data/models/zukko_chat_user.dart';
import '../data/remote/api/widget_auth_interceptor.dart';
import '../data/remote/api/widget_session.dart';
import '../data/remote/api/widget_session_api.dart';
import '../data/remote/api/zukko_chat_client_service.dart';
import '../data/remote/realtime/zukko_chat_socket.dart';
import '../data/zukko_chat_repository.dart';
import '../shared/http_client.dart';
import '../shared/safe_invoke.dart';
import '../shared/url_policy.dart';
import 'zukko_chat_callbacks.dart';

/// Everything [wireZukkoChat] builds for a client.
typedef ZukkoChatWiring = ({
  ZukkoChatRepositoryImpl repository,
  WidgetSession session,
  List<Dio> dios,
});

/// The composition root: validates [baseUrl], opens the storage and wires
/// session, interceptor, service, socket and repository by constructor
/// injection. Throws only an [ArgumentError] for a bad [baseUrl]; nothing is
/// requested yet (the caller runs `repository.initialize()`).
Future<ZukkoChatWiring> wireZukkoChat({
  required String baseUrl,
  required String websiteToken,
  required ZukkoChatUser? user,
  required bool enablePersistence,
  required ZukkoChatCallbacks? callbacks,
  Duration? socketSubscribeTimeout,
}) async {
  final base = validateBaseUrl(baseUrl);
  final url = baseUrl.trim(); // the one form used for Dio and the storage key

  final storage = await openStorage(
    persist: enablePersistence,
    instanceKey: zukkoChatInstanceKey(
      baseUrl: url,
      websiteToken: websiteToken,
      userIdentifier: user?.identifier,
      identifierHash: user?.identifierHash,
    ),
    onError: (e) {
      final cb = callbacks?.onError;
      if (cb != null) safeInvoke(() => cb(e), 'onError');
    },
  );

  final bareDio = zukkoChatDio(url);
  final session = WidgetSession(
    api: WidgetSessionApi(bareDio, websiteToken),
    storage: storage,
    user: user,
  );
  final dio = zukkoChatDio(url);
  dio.interceptors.add(WidgetAuthInterceptor(session: session, dio: dio));

  final repository = ZukkoChatRepositoryImpl(
    clientService: ZukkoChatClientServiceImpl(dio: dio),
    socket: ZukkoChatSocket(
      url: zukkoChatCableUri(base),
      tokenProvider: () => storage.contact.get()?.pubsubToken,
      subscribeTimeout: socketSubscribeTimeout,
    ),
    localStorage: storage,
    streamCallbacks: callbacks ?? ZukkoChatCallbacks(),
    session: session, // registers itself as the session's listener
  );
  return (repository: repository, session: session, dios: [bareDio, dio]);
}
