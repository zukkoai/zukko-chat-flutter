/// Every user-visible string of the native chat UI.
class ChatwootL10n {
  /// Placeholder for the text field
  final String inputPlaceholder;

  /// Status text when the conversation is online
  final String onlineText;

  /// Status text when the conversation is offline
  final String offlineText;

  /// Status text when the agent is typing
  final String typingText;

  /// Message when agent resolves conversation
  final String conversationResolvedMessage;

  /// Name of the system author of [conversationResolvedMessage]
  final String botName;

  /// Footer text, see `ChatwootChatOptions.showBranding`
  final String poweredByText;

  /// Tooltip / semantics label of the dialog close button
  final String closeLabel;

  /// Text of a message that only has attachments
  final String attachmentLabel;

  /// Screen reader hint on a message that failed to send
  final String messageFailedHint;

  /// Shown when the chat could not be started
  final String connectionErrorText;

  /// Label of the button that tries to start the chat again
  final String retryLabel;

  const ChatwootL10n({
    this.inputPlaceholder = 'Type your message',
    this.onlineText = 'Online',
    this.offlineText = "We're away at the moment",
    this.typingText = 'typing...',
    this.conversationResolvedMessage =
        'Your ticket has been marked as resolved',
    this.botName = 'Bot',
    this.poweredByText = 'Powered by Chatwoot',
    this.closeLabel = 'Close',
    this.attachmentLabel = 'Attachment',
    this.messageFailedHint = 'Failed to send. Tap to retry',
    this.connectionErrorText = 'Could not connect to the chat',
    this.retryLabel = 'Retry',
  });

  @override
  bool operator ==(Object other) =>
      other is ChatwootL10n &&
      other.inputPlaceholder == inputPlaceholder &&
      other.onlineText == onlineText &&
      other.offlineText == offlineText &&
      other.typingText == typingText &&
      other.conversationResolvedMessage == conversationResolvedMessage &&
      other.botName == botName &&
      other.poweredByText == poweredByText &&
      other.closeLabel == closeLabel &&
      other.attachmentLabel == attachmentLabel &&
      other.messageFailedHint == messageFailedHint &&
      other.connectionErrorText == connectionErrorText &&
      other.retryLabel == retryLabel;

  @override
  int get hashCode => Object.hash(
    inputPlaceholder,
    onlineText,
    offlineText,
    typingText,
    conversationResolvedMessage,
    botName,
    poweredByText,
    closeLabel,
    attachmentLabel,
    messageFailedHint,
    connectionErrorText,
    retryLabel,
  );
}
