/// Hive box names. They are the file names on users' devices, so the values are
/// pinned as literals: renaming one would orphan persisted data.
abstract final class ZukkoChatBoxNames {
  static const contacts = 'ChatwootContactBoxNames.CONTACTS.enc';
  static const conversations = 'ChatwootConversationBoxNames.CONVERSATIONS.enc';
  static const messages = 'ChatwootMessagesBoxNames.MESSAGES.enc';

  /// Retired: the SDK no longer stores a user. The name stays reserved (never
  /// reuse it for other data); the box is only deleted on a full wipe, to
  /// remove what earlier versions persisted there.
  static const users = 'ChatwootUserBoxNames.USERS.enc';
}
