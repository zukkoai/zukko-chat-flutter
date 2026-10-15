import 'core/chatwoot_client.dart';
import 'data/models/chatwoot_user.dart';

/// One call for logout: forgets the contact, conversation and messages this
/// SDK persisted for [user] ([ChatwootClient.clearData], using the user's
/// `identifier` and `identifierHash`).
///
/// Pass the same [baseUrl], [inboxIdentifier] and [user] the client was
/// created with, and dispose running clients first.
Future<void> chatwootSignOut({
  required String baseUrl,
  required String inboxIdentifier,
  ChatwootUser? user,
}) => ChatwootClient.clearData(
  baseUrl: baseUrl,
  inboxIdentifier: inboxIdentifier,
  userIdentifier: user?.identifier,
  identifierHash: user?.identifierHash,
);
