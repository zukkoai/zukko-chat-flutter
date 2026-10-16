import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

import 'live_config.dart';
import 'not_configured_view.dart';

/// The real SDK against a real server. This file is the reference for the
/// whole public UI API: every parameter of [ZukkoChat], [ZukkoChatOptions],
/// [ZukkoChatTheme], [ZukkoChatCallbacks] and [ZukkoChatInteractions] is
/// written out below with what it does and its default. Most are set to their
/// default, so you can delete the lines you do not need.
class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({
    super.key,
    this.config = const LiveConfig(),
    this.style = ZukkoChatStyle.smoothSilk,
  });

  final LiveConfig config;

  /// Chosen on the home screen.
  final ZukkoChatStyle style;

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  // A new key makes Flutter build a brand-new ZukkoChat (and a new client)
  // after sign-out, so the chat starts from a clean state.
  var _session = 0;

  // True while the chat widget is removed from the tree during sign-out.
  var _signingOut = false;

  void _snack(String text) =>
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(text)));

  /// Sign-out order matters:
  ///
  ///  1. REMOVE the ZukkoChat widget from the tree. Disposing it closes the
  ///     client: websocket, timers and the open storage boxes.
  ///  2. WAIT for that frame to finish, so the dispose really happened.
  ///  3. CLEAR the stored data with [zukkoChatSignOut]. Clearing while a
  ///     client is still running would let it write the data straight back.
  ///  4. Build a NEW ZukkoChat with a fresh key.
  ///
  /// Pass the same baseUrl / websiteToken / user the chat was created with.
  Future<void> _signOut() async {
    final c = widget.config;
    setState(() => _signingOut = true); // 1
    await WidgetsBinding.instance.endOfFrame; // 2
    await zukkoChatSignOut(
      baseUrl: c.baseUrl,
      websiteToken: c.websiteToken,
      user: c.user,
    ); // 3
    if (!mounted) return;
    setState(() {
      _signingOut = false;
      _session++; // 4
    });
    _snack('Signed out: local chat data cleared');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    if (!c.isConfigured) return const NotConfiguredView();
    if (_signingOut) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ZukkoChat(
      // Standard Flutter key; see _session above.
      key: ValueKey(_session),

      // Text in the chat header. Default: ZukkoChatL10n.headerTitle.
      title: 'Live chat',

      // What to connect to and how the chat looks and behaves.
      options: ZukkoChatOptions(
        // Your Zukko Chat server (required, https only).
        baseUrl: c.baseUrl,

        // Which inbox to talk to (required).
        websiteToken: c.websiteToken,

        // Identity of the visitor; null = anonymous. See live_config.dart.
        user: c.user,

        // Keep contact, conversation and the newest messages on the device so
        // the chat opens instantly and works offline. Default: true. When
        // false everything lives in memory and is dropped with the client.
        enablePersistence: true,

        // Look of the chat: smoothSilk (default), minimalClean, threadFeed.
        style: widget.style,

        // Base theme: brightness plus optional overrides. Default: a
        // ZukkoChatTheme registered in ThemeData.extensions, else one derived
        // from the ambient theme (so dark mode just follows the app).
        // fromThemeData is that derivation made explicit.
        theme: ZukkoChatTheme.fromThemeData(Theme.of(context)).copyWith(
          // Force one font on all chat text. Default: null, the style's own
          // bundled font (Manrope / Geist / Onest).
          // fontFamily: 'Roboto',

          // Brand color: send button, links. Default: null, the style's own.
          // accentColor: Colors.teal,

          // Chat background. Default: null, the style's own.
          // backgroundColor: Colors.white,

          // Gap between screen edge and messages/composer. Default: 16.
          horizontalPadding: 16,
        ),

        // All UI strings. Default: null, the built-in translation of the
        // ambient locale (en, ru, uz Latin, uz Cyrillic, tr, kaa). Pass a
        // ZukkoChatL10n to override texts or force a language, e.g.
        // ZukkoChatL10n.forLocale(const Locale('ru')).
        l10n: null,

        // Format of the time under each message. Default: DateFormat.Hm()
        // (24h, "14:05").
        timeFormat: DateFormat.Hm(),

        // Attachment button: photos and files via the system picker, up to
        // ZukkoChatUpload.maxSizeMb each. Default: true.
        enableAttachments: true,

        // Hold-to-record microphone for voice messages (max 5 minutes).
        // Default: true. Needs the microphone permission entries in
        // AndroidManifest.xml / Info.plist (see the package README).
        enableVoiceMessages: true,

        // Fetch a preview card for the first link in a message. The DEVICE
        // contacts the linked site, which reveals its IP; set false for
        // privacy. Default: true.
        enableLinkPreviews: true,
      ),

      // Client events (all optional, default: none). A callback that throws
      // never breaks the SDK.
      callbacks: ZukkoChatCallbacks(
        // Realtime connection changed (connecting, subscribed, backoff, ...).
        // Good place for an offline banner; missed messages are refetched
        // automatically after reconnect.
        onConnectionStateChanged: (s) => debugPrint('connection: ${s.name}'),

        // Any SDK error. `type` says what failed, `cause` is safe to log.
        onError: (e) => _snack('Error: ${e.type.name}'),

        // Conversation created or changed by the server (e.g. resolved).
        onConversationUpdated: (c) => debugPrint('conversation: ${c.id}'),

        // An agent resolved the conversation.
        onConversationResolved: () => debugPrint('conversation resolved'),

        // The session was replaced (new contact); old messages were dropped.
        onSessionReset: () => debugPrint('session reset'),

        // A message from the agent arrived.
        onMessageReceived: (m) => debugPrint('received: ${m.id}'),

        // A message was edited/updated on the server.
        onMessageUpdated: (m) => debugPrint('updated: ${m.id}'),

        // The server accepted a message you sent (message + your echoId).
        onMessageSent: (m, echoId) => debugPrint('sent: $echoId'),

        // The visitor's own message came back over the websocket.
        onMessageDelivered: (m, echoId) => debugPrint('delivered: $echoId'),

        // Messages loaded from the device / from the server.
        onPersistedMessagesRetrieved: (l) =>
            debugPrint('from device: ${l.length}'),
        onMessagesRetrieved: (l) => debugPrint('from server: ${l.length}'),

        // The agent started / stopped typing.
        onConversationStartedTyping: () => debugPrint('agent typing'),
        onConversationStoppedTyping: () => debugPrint('agent stopped typing'),

        // Agent presence changed.
        onConversationIsOnline: () => debugPrint('agent online'),
        onConversationIsOffline: () => debugPrint('agent offline'),

        // Low-level websocket events; rarely needed.
        onWelcome: () => debugPrint('ws welcome'),
        onPing: () {},
        onConfirmedSubscription: () => debugPrint('ws subscribed'),
      ),

      // UI events (default: ZukkoChatInteractions(), nothing set).
      interactions: ZukkoChatInteractions(
        // Scrolled to the oldest loaded message; load older ones here.
        onEndReached: () async => debugPrint('top of the list reached'),

        // Fraction (0..1) of the list at which onEndReached fires. null keeps
        // the SDK default (0.01: right at the top), so older messages load
        // only when the user really reaches the oldest one.
        onEndReachedThreshold: null,

        // Message tapped / long-pressed. `Message` is the flutter_chat_core
        // type re-exported by the SDK.
        onMessageTap: (message) => debugPrint('tap: ${message.id}'),
        onMessageLongPress: (context, message) =>
            debugPrint('long press: ${message.id}'),

        // The user sent a text message.
        onSendPressed: (text) => debugPrint('send pressed (${text.length})'),

        // Menu button in the header; hidden when null. Here: sign out.
        onMorePressed: _signOut,
      ),
    );
  }
}
