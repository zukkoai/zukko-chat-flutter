import 'dart:io';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:path_provider/path_provider.dart';

// Replace with your installation.
const _baseUrl = 'https://app.chatwoot.com';
const _websiteToken = 'websiteToken'; // web widget channel
const _inboxIdentifier = 'inboxIdentifier'; // API channel

final _user = ChatwootUser(
  identifier: 'test@test.com',
  name: 'Tester test',
  email: 'test@test.com',
);

const _nativeOptions = ChatwootChatOptions(
  baseUrl: _baseUrl,
  inboxIdentifier: _inboxIdentifier,
);

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Chatwoot Example',
        theme: ThemeData(colorSchemeSeed: Colors.blue),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.blue, brightness: Brightness.dark),
        home: const MyHomePage(),
      );
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chatwoot Example')),
        body: ListView(
          children: [
            ListTile(
              title: const Text('Native chat (page)'),
              subtitle: const Text('ChatwootChat'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => ChatwootChat(
                            options: ChatwootChatOptions(
                                baseUrl: _baseUrl,
                                inboxIdentifier: _inboxIdentifier,
                                user: _user),
                            appBar: AppBar(title: const Text('Support')),
                          ))),
            ),
            ListTile(
              title: const Text('Native chat (dialog)'),
              subtitle: const Text('ChatwootChatDialog'),
              onTap: () => ChatwootChatDialog.show(context,
                  options: _nativeOptions, title: 'Support'),
            ),
            ListTile(
              title: const Text('Web widget'),
              subtitle: const Text('ChatwootWidget'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const WebWidgetPage())),
            ),
          ],
        ),
      );
}

class WebWidgetPage extends StatelessWidget {
  const WebWidgetPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chatwoot Widget')),
        body: ChatwootWidget(
          websiteToken: _websiteToken,
          baseUrl: _baseUrl,
          user: _user,
          locale: 'en',
          closeWidget: () => Navigator.maybePop(context),
          // attachment only works on android for now
          onAttachFile: _androidFilePicker,
          onError: (description) => debugPrint('widget error: $description'),
        ),
      );
}

Future<List<String>> _androidFilePicker() async {
  final picker = image_picker.ImagePicker();
  final photo =
      await picker.pickImage(source: image_picker.ImageSource.gallery);

  if (photo == null) {
    return [];
  }

  final imageData = await photo.readAsBytes();
  final decodedImage = image.decodeImage(imageData);
  final scaledImage = image.copyResize(decodedImage!, width: 500);
  final jpg = image.encodeJpg(scaledImage, quality: 90);

  final filePath = (await getTemporaryDirectory()).uri.resolve(
        './image_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
  final file = await File.fromUri(filePath).create(recursive: true);
  await file.writeAsBytes(jpg, flush: true);

  return [file.uri.toString()];
}
