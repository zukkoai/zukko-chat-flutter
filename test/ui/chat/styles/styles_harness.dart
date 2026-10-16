import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/audio_playback.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/gallery_message.dart';
import 'package:zukko_chat_flutter/src/ui/chat/zukko_chat_style.dart';
import 'package:zukko_chat_flutter/src/ui/l10n/zukko_chat_l10n.dart';

/// Shared setup of the style tests: one message of every kind, the builders'
/// environment and a host app.
final sampleTime = DateTime.utc(2026, 10, 15, 9, 41);

List<Message> sampleMessages() => [
  TextMessage(
    id: 'a1',
    authorId: 'agent',
    text: 'Hello! See https://zukko.ai/docs for the details.',
    createdAt: sampleTime,
  ),
  TextMessage(
    id: 'u1',
    authorId: 'me',
    text: 'Thanks, one more thing',
    createdAt: sampleTime,
  ),
  ImageMessage(
    id: 'i1',
    authorId: 'agent',
    source: '',
    text: 'A caption',
    createdAt: sampleTime,
  ),
  ImageMessage(
    id: 'i2',
    authorId: 'me',
    source: '',
    text: 'Mine',
    createdAt: sampleTime,
  ),
  GalleryMessage.create(
    id: 'g1',
    authorId: 'agent',
    images: List.filled(5, ''),
    caption: 'Five images',
    createdAt: sampleTime,
  ),
  FileMessage(
    id: 'f1',
    authorId: 'agent',
    source: '',
    name: 'invoice.pdf',
    size: 120000,
    createdAt: sampleTime,
  ),
  FileMessage(
    id: 'f2',
    authorId: 'me',
    source: '',
    name: 'photo-notes.txt',
    size: 2048,
    createdAt: sampleTime,
  ),
  AudioMessage(
    id: 'v1',
    authorId: 'agent',
    source: '',
    duration: const Duration(seconds: 12),
    createdAt: sampleTime,
  ),
  AudioMessage(
    id: 'v2',
    authorId: 'me',
    source: '',
    duration: const Duration(seconds: 7),
    createdAt: sampleTime,
  ),
  TextMessage(
    id: 'u2',
    authorId: 'me',
    text: 'Sending...',
    createdAt: sampleTime,
    status: MessageStatus.sending,
  ),
  TextMessage(
    id: 'u3',
    authorId: 'me',
    text: 'This one failed',
    createdAt: sampleTime,
    status: MessageStatus.error,
  ),
];

/// Calls the matching builder of [b] for [m].
Widget messageOf(Builders b, Message m, bool me) {
  Widget call<T extends Message>(
    Widget Function(
      BuildContext,
      T,
      int, {
      required bool isSentByMe,
      MessageGroupStatus? groupStatus,
    })?
    builder,
  ) => Builder(
    builder: (context) => builder!(context, m as T, 0, isSentByMe: me),
  );
  final child = switch (m) {
    TextMessage() => call<TextMessage>(b.textMessageBuilder),
    ImageMessage() => call<ImageMessage>(b.imageMessageBuilder),
    FileMessage() => call<FileMessage>(b.fileMessageBuilder),
    AudioMessage() => call<AudioMessage>(b.audioMessageBuilder),
    CustomMessage() => call<CustomMessage>(b.customMessageBuilder),
    _ => const SizedBox.shrink(),
  };
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    ),
  );
}

ChatMessageEnv chatEnv() => ChatMessageEnv(
  l10n: const ZukkoChatL10n(),
  timeFormat: DateFormat('HH:mm'),
  userById: (id) => User(id: id, name: id == 'me' ? 'Me' : 'Agent'),
  authorName: (id, isSentByMe) => isSentByMe ? 'You' : 'Agent',
  horizontalPadding: 16,
  audio: AudioPlaybackController(),
);

Widget frame(ThemeData theme, Color background, Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: theme,
  home: Scaffold(
    backgroundColor: background,
    body: RepaintBoundary(
      key: const ValueKey('shot'),
      child: ColoredBox(color: background, child: child),
    ),
  ),
);
