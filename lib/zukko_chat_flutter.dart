/// Zukko Chat Flutter SDK. Everything not exported here is internal.
library;

export 'src/core/zukko_chat_sign_out.dart';
export 'src/core/zukko_chat_callbacks.dart';
export 'src/core/zukko_chat_client.dart';
export 'src/core/zukko_chat_client_exception.dart';
export 'src/core/zukko_chat_upload.dart';
export 'src/core/zukko_chat_connection_state.dart';
export 'src/data/models/zukko_chat_attachment.dart' show ZukkoChatAttachment;
export 'src/data/models/zukko_chat_config.dart';
export 'src/data/models/zukko_chat_conversation.dart';
export 'src/data/models/zukko_chat_event_message_user.dart';
export 'src/data/models/zukko_chat_message.dart';
export 'src/data/models/zukko_chat_user.dart';
export 'src/data/remote/realtime/zukko_chat_action_data.dart'
    show ZukkoChatActionType;

// Type of the message in the UI callbacks (ZukkoChatInteractions).
export 'package:flutter_chat_core/flutter_chat_core.dart' show Message;

export 'src/ui/chat/zukko_chat_style.dart' show ZukkoChatStyle;
export 'src/ui/chat/zukko_chat_options.dart';
export 'src/ui/chat/zukko_chat_page.dart';
export 'src/ui/l10n/zukko_chat_l10n.dart';
export 'src/ui/theme/zukko_chat_theme.dart';
