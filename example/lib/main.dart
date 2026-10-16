import 'package:flutter/material.dart';

import 'home_screen.dart';

// HOW THIS EXAMPLE IS ORGANISED (read the files in this order)
//
//  1. lib/main.dart                  (this file) app entry, light/dark theme.
//  2. lib/home_screen.dart           pick a chat style, toggle dark mode,
//                                    open the chat, sign out.
//  3. lib/live/live_config.dart      reads --dart-define values and builds the
//                                    ZukkoChatUser (the visitor's identity).
//  4. lib/live/live_chat_screen.dart the ZukkoChat widget with EVERY public
//                                    parameter written out and explained.
//  5. lib/live/not_configured_view.dart shown while the dart-defines are
//                                    missing, tells you what to run.
//
// The example talks to a REAL Zukko Chat server; there are no fakes. See
// example/README.md for how to run it and where each value comes from.

/// Program entry point.
void main() => runApp(const ExampleApp());

/// Root widget. It only owns one piece of state: light or dark mode.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  var _mode = ThemeMode.light;

  void _toggleMode() => setState(
    () => _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Zukko Chat example',
    debugShowCheckedModeBanner: false,
    // The SDK follows the ambient theme: when ZukkoChatOptions.theme is null
    // it derives light/dark from Theme.of(context).brightness. So switching
    // `themeMode` here also switches the chat. (live_chat_screen.dart passes
    // the theme explicitly to show the API.)
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    themeMode: _mode,
    home: HomeScreen(dark: _mode == ThemeMode.dark, onToggleDark: _toggleMode),
  );
}
