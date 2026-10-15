import 'zukko_chat_client.dart';
import '../data/models/zukko_chat_user.dart';

/// One call for logout: forgets the contact, conversation and messages this
/// SDK persisted for [user] ([ZukkoChatClient.clearData]: every record of that
/// `identifier`, whatever `identifierHash` it was stored with; use
/// [ZukkoChatClient.clearAllData] to wipe everything).
///
/// Pass the same [baseUrl], [websiteToken] and [user] the client was
/// created with, and dispose running clients first.
Future<void> zukkoChatSignOut({
  required String baseUrl,
  required String websiteToken,
  ZukkoChatUser? user,
}) => ZukkoChatClient.clearData(
  baseUrl: baseUrl,
  websiteToken: websiteToken,
  userIdentifier: user?.identifier,
);
