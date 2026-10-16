import 'package:flutter/material.dart';

import 'live/live_chat_screen.dart';

/// Entry screen: the live chat against a real server. The switch toggles
/// light / dark.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.dark, required this.onToggleDark});

  final bool dark;
  final VoidCallback onToggleDark;

  static const _maxWidth = 360.0;
  static const _gap = 12.0;
  static const _buttonSize = Size.fromHeight(52);

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

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
