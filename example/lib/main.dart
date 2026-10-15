import 'package:flutter/material.dart';

import 'home_screen.dart';

void main() => runApp(const ExampleApp());

/// Demo of the SDK: three chat styles on offline data, and a live chat.
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
    title: 'Zukko chat styles',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    themeMode: _mode,
    home: HomeScreen(dark: _mode == ThemeMode.dark, onToggleDark: _toggleMode),
  );
}
