import 'dart:convert';

import 'chatwoot_event.dart';

/// One decoded ActionCable frame.
sealed class Frame {
  const Frame();

  /// Decodes a raw websocket payload. Never throws: anything that is not a
  /// well-formed frame becomes [UnknownFrame].
  static Frame parse(Object? raw) {
    try {
      if (raw is! String) return const UnknownFrame();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const UnknownFrame();
      switch (json['type']) {
        case 'welcome':
          return const WelcomeFrame();
        case 'ping':
          return const PingFrame();
        case 'confirm_subscription':
          return const ConfirmFrame();
        case 'reject_subscription':
          return const RejectFrame();
        case 'disconnect':
          return DisconnectFrame(
            reason: json['reason'] as String?,
            reconnect: json['reconnect'] != false,
          );
      }
      final message = json['message'];
      if (message is Map<String, dynamic>) {
        return EventFrame(ChatwootEventMessage.fromJson(message));
      }
    } catch (_) {
      // fall through: a malformed frame must never break the connection
    }
    return const UnknownFrame();
  }
}

class WelcomeFrame extends Frame {
  const WelcomeFrame();
}

class PingFrame extends Frame {
  const PingFrame();
}

class ConfirmFrame extends Frame {
  const ConfirmFrame();
}

class RejectFrame extends Frame {
  const RejectFrame();
}

/// The server closes the connection; [reconnect] says whether retrying is
/// allowed (`false` e.g. for an unauthorized connection).
class DisconnectFrame extends Frame {
  const DisconnectFrame({this.reason, required this.reconnect});

  final String? reason;
  final bool reconnect;
}

class EventFrame extends Frame {
  const EventFrame(this.message);

  final ChatwootEventMessage message;
}

class UnknownFrame extends Frame {
  const UnknownFrame();
}
