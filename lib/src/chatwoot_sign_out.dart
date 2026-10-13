import 'core/chatwoot_client.dart';
import 'data/models/chatwoot_user.dart';
import 'ui/webview/chatwoot_widget.dart';
import 'ui/webview/token_store.dart';

/// One call for logout: forgets everything this SDK stored for [user].
///
/// - [inboxIdentifier] given: the native client's persisted contact,
///   conversation and messages ([ChatwootClient.clearData], using the user's
///   `identifier` and `identifierHash`).
/// - [websiteToken] given: the webview conversation token plus the webview's
///   cookies, local storage and cache ([ChatwootWidget.clearStoredConversation]).
///
/// Pass the same [baseUrl] and [user] the client/widget was created with.
/// Dispose running clients and remove the widget first.
Future<void> chatwootSignOut({
  required String baseUrl,
  String? inboxIdentifier,
  String? websiteToken,
  ChatwootUser? user,
  ChatwootTokenStore tokenStore = const SecureTokenStore(),
}) async {
  assert(
    inboxIdentifier != null || websiteToken != null,
    'pass inboxIdentifier (native client), websiteToken (webview) or both',
  );
  if (inboxIdentifier != null) {
    await ChatwootClient.clearData(
      baseUrl: baseUrl,
      inboxIdentifier: inboxIdentifier,
      userIdentifier: user?.identifier,
      identifierHash: user?.identifierHash,
    );
  }
  if (websiteToken != null) {
    await ChatwootWidget.clearStoredConversation(
      baseUrl: baseUrl,
      websiteToken: websiteToken,
      user: user,
      tokenStore: tokenStore,
    );
  }
}
