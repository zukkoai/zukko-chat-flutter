import 'package:flutter/material.dart';

/// Shown instead of the chat while no `--dart-define` values are given.
class NotConfiguredView extends StatelessWidget {
  const NotConfiguredView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Live chat')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Live chat is not configured.\n\nRun the example with\n'
          '--dart-define=ZUKKO_BASE_URL=...\n'
          '--dart-define=ZUKKO_WEBSITE_TOKEN=...\n'
          '(optional: ZUKKO_USER_ID, ZUKKO_USER_HASH).',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
