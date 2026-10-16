import 'package:flutter/material.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

import 'live/live_chat_screen.dart';
import 'live/live_config.dart';

/// Entry screen. Four things happen here:
///
///  1. pick one of the three built-in chat styles ([ZukkoChatStyle]),
///  2. switch dark mode (the chat follows the app theme),
///  3. open the chat,
///  4. sign out (forget the locally stored chat data).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dark,
    required this.onToggleDark,
    this.config = const LiveConfig(),
  });

  final bool dark;
  final VoidCallback onToggleDark;

  /// Server settings. Injectable so tests can pass fake values.
  final LiveConfig config;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _style = ZukkoChatStyle.smoothSilk;

  // Human-readable names of the three styles.
  static const _styleNames = {
    ZukkoChatStyle.smoothSilk: 'Silk',
    ZukkoChatStyle.minimalClean: 'Minimal',
    ZukkoChatStyle.threadFeed: 'Thread',
  };

  void _openChat() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => LiveChatScreen(config: widget.config, style: _style),
    ),
  );

  /// Sign out from the home screen. The chat screen is not on the stack here,
  /// so no ZukkoChat is running: the "dispose first, then clear" rule holds.
  Future<void> _signOut() async {
    final c = widget.config;
    final messenger = ScaffoldMessenger.of(context);
    // One call wipes the contact, conversation and messages the SDK stored
    // on this device for that user.
    await zukkoChatSignOut(
      baseUrl: c.baseUrl,
      websiteToken: c.websiteToken,
      user: c.user,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Signed out: local chat data cleared')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Style picker: the chosen value is passed to the chat screen,
                // which hands it to ZukkoChatOptions.style.
                SegmentedButton<ZukkoChatStyle>(
                  segments: [
                    for (final entry in _styleNames.entries)
                      ButtonSegment(value: entry.key, label: Text(entry.value)),
                  ],
                  selected: {_style},
                  onSelectionChanged: (v) => setState(() => _style = v.first),
                ),
                SwitchListTile(
                  title: const Text('Dark'),
                  value: widget.dark,
                  onChanged: (_) => widget.onToggleDark(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _openChat,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Open chat'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
