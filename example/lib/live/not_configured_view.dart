import 'package:flutter/material.dart';

/// Shown instead of the chat while the required `--dart-define` values are
/// missing, so a first run explains itself instead of failing silently.
class NotConfiguredView extends StatelessWidget {
  const NotConfiguredView({super.key});

  /// The exact command to run; also what the test looks for.
  static const command =
      'flutter run \\\n'
      '  --dart-define=ZUKKO_BASE_URL=https://chat.example.com \\\n'
      '  --dart-define=ZUKKO_WEBSITE_TOKEN=<website token> \\\n'
      '  --dart-define=ZUKKO_USER_ID=user-42 \\\n'
      '  --dart-define=ZUKKO_USER_HASH=<hmac of the user id>';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Live chat')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Live chat is not configured.\n\n'
                'Run the example with the values of your Zukko Chat inbox. '
                'ZUKKO_BASE_URL (https) and ZUKKO_WEBSITE_TOKEN are required; '
                'ZUKKO_USER_ID and ZUKKO_USER_HASH are optional (without a user '
                'id you chat as an anonymous visitor).',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              SelectableText(
                command,
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
