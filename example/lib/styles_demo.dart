import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';
import 'package:flutter/material.dart';

import 'demo_client.dart';

/// Three buttons, one per chat style; each opens the full chat screen on
/// demo data (no server). The switch (or the chat's menu button) toggles
/// light / dark.
class StylesHomeScreen extends StatelessWidget {
  final bool dark;
  final VoidCallback onToggleDark;

  const StylesHomeScreen({
    super.key,
    required this.dark,
    required this.onToggleDark,
  });

  static const _styles = [
    (ZukkoChatStyle.smoothSilk, 'Smooth Silk'),
    (ZukkoChatStyle.minimalClean, 'Minimal Clean'),
    (ZukkoChatStyle.threadFeed, 'Thread Feed'),
  ];

  void _open(BuildContext context, ZukkoChatStyle style) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ZukkoChat(
        title: 'Zukko AI',
        options: ZukkoChatOptions(
          baseUrl: 'https://demo.zukko.ai',
          websiteToken: 'demo',
          enablePersistence: false,
          style: style,
          l10n: ZukkoChatL10n.uzLatn,
        ),
        // Demo only: the offline client instead of a real server.
        // ignore: invalid_use_of_visible_for_testing_member
        clientFactory: DemoZukkoChatClient.create,
        interactions: ZukkoChatInteractions(onMorePressed: onToggleDark),
      ),
    ),
  );

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
                for (final (style, label) in _styles) ...[
                  FilledButton(
                    onPressed: () => _open(context, style),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(label),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
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
