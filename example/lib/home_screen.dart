import 'package:flutter/material.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

import 'demo/demo_client.dart';
import 'live/live_chat_screen.dart';

/// Entry screen: the three chat styles on offline demo data, and the live
/// chat against a real server. The switch toggles light / dark.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.dark, required this.onToggleDark});

  final bool dark;
  final VoidCallback onToggleDark;

  static const _styles = [
    (ZukkoChatStyle.smoothSilk, 'Smooth Silk'),
    (ZukkoChatStyle.minimalClean, 'Minimal Clean'),
    (ZukkoChatStyle.threadFeed, 'Thread Feed'),
  ];

  static const _maxWidth = 360.0;
  static const _gap = 12.0;
  static const _buttonSize = Size.fromHeight(52);

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  Widget _demoChat(ZukkoChatStyle style) => ZukkoChat(
    title: 'Zukko AI',
    options: ZukkoChatOptions(
      baseUrl: 'https://demo.zukko.ai',
      websiteToken: 'demo',
      enablePersistence: false,
      style: style,
      l10n: ZukkoChatL10n.uzLatn,
    ),
    clientFactory: DemoZukkoChatClient.create,
    interactions: ZukkoChatInteractions(onMorePressed: onToggleDark),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (style, label) in _styles) ...[
                  FilledButton(
                    onPressed: () => _push(context, _demoChat(style)),
                    style: FilledButton.styleFrom(minimumSize: _buttonSize),
                    child: Text(label),
                  ),
                  const SizedBox(height: _gap),
                ],
                OutlinedButton(
                  onPressed: () => _push(context, const LiveChatScreen()),
                  style: OutlinedButton.styleFrom(minimumSize: _buttonSize),
                  child: const Text('Live chat'),
                ),
                const SizedBox(height: _gap),
                SwitchListTile(
                  title: const Text('Dark'),
                  value: dark,
                  onChanged: (_) => onToggleDark(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
