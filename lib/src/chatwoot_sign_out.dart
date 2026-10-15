import 'core/chatwoot_client.dart';
import 'data/models/chatwoot_user.dart';

/// One call for logout: forgets the contact, conversation and messages this
/// SDK persisted for [user] ([ChatwootClient.clearData]: every record of that
/// `identifier`, whatever `identifierHash` it was stored with; use
/// [ChatwootClient.clearAllData] to wipe everything).
///
/// Pass the same [baseUrl], [websiteToken] and [user] the client was
/// created with, and dispose running clients first.
Future<void> chatwootSignOut({
  required String baseUrl,
  required String websiteToken,
  ChatwootUser? user,
}) => ChatwootClient.clearData(
  baseUrl: baseUrl,
  websiteToken: websiteToken,
  userIdentifier: user?.identifier,
);
