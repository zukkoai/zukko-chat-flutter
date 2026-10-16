import 'package:flutter/material.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

import 'live_config.dart';
import 'not_configured_view.dart';

/// The real SDK against a real server: identified user, callbacks, sign-out.
class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key, this.config = const LiveConfig()});

  final LiveConfig config;

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  // Rebuilt after sign-out, so the chat starts from a clean state.
  var _session = 0;

  void _snack(String text) =>
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _signOut() async {
    final c = widget.config;
    await zukkoChatSignOut(
      baseUrl: c.baseUrl,
      websiteToken: c.websiteToken,
      user: c.user,
    );
    if (!mounted) return;
    setState(() => _session++);
    _snack('Signed out: local chat data cleared');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    if (!c.isConfigured) return const NotConfiguredView();
    return ZukkoChat(
      key: ValueKey(_session),
      title: 'Live chat',
      options: ZukkoChatOptions(
        baseUrl: c.baseUrl,
        websiteToken: c.websiteToken,
        user: c.user,
      ),
      callbacks: ZukkoChatCallbacks(
        onError: (e) => _snack('Error: ${e.type.name}'),
        onConnectionStateChanged: (s) => debugPrint('connection: ${s.name}'),
        onConversationUpdated: (c) => debugPrint('conversation: ${c.id}'),
      ),
      interactions: ZukkoChatInteractions(onMorePressed: _signOut),
    );
  }
}
