/// REST paths of the public client API. Callers pass either real identifiers
/// or the interceptor's placeholders.
abstract final class ChatwootPaths {
  static String contacts(String inbox) =>
      '/public/api/v1/inboxes/$inbox/contacts';

  static String contact(String inbox, String contact) =>
      '${contacts(inbox)}/$contact';

  static String conversations(String inbox, String contact) =>
      '${ChatwootPaths.contact(inbox, contact)}/conversations';

  static String messages(String inbox, String contact, String conversation) =>
      '${conversations(inbox, contact)}/$conversation/messages';
}
