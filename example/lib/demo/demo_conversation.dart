import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

const _agent = ZukkoChatEventMessageUser(id: 1, name: 'Zukko AI');

const _sampleAudio =
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

/// Attachment JSON in the shape the server returns (the SDK parses it).
Map<String, dynamic> _attachment(String type, String url, int? size) => {
  'file_type': type,
  'data_url': url,
  'file_size': size,
};

Map<String, dynamic> _image(String seed) =>
    _attachment('image', 'https://picsum.photos/seed/$seed/600/450', 120000);

/// Stands in for the server's stored copy of an uploaded file.
Map<String, dynamic> demoHostedAttachment(ZukkoChatUpload file) {
  if (file.isImage) return _image('${file.name.hashCode}');
  if (file.isAudio) return _attachment('audio', _sampleAudio, file.size);
  return _attachment(
    'file',
    'https://example.com/files/${Uri.encodeComponent(file.name)}',
    file.size,
  );
}

ZukkoChatMessage demoMessage(
  int id, {
  required String? content,
  bool mine = false,
  int minutesAgo = 0,
  List<dynamic>? attachments,
}) => ZukkoChatMessage(
  id: id,
  content: content,
  messageType: mine ? 0 : 1,
  contentType: 'text',
  contentAttributes: null,
  createdAt: DateTime.now()
      .toUtc()
      .subtract(Duration(minutes: minutesAgo))
      .toIso8601String(),
  conversationId: 1,
  attachments: attachments,
  sender: mine ? null : _agent,
);

/// The fixed conversation: text, link, images, file, voice.
List<ZukkoChatMessage> demoConversation() {
  var id = 1;
  return [
    demoMessage(
      id++,
      minutesAgo: 30,
      content:
          'Assalomu alaykum! Men AI yordamchiman. Buyurtma, toʻlov yoki '
          'yetkazib berish haqida soʻrashingiz mumkin.',
    ),
    demoMessage(
      id++,
      minutesAgo: 28,
      mine: true,
      content: 'Shu mahsulotni olgandim: https://zukko.ai',
    ),
    demoMessage(
      id++,
      minutesAgo: 27,
      content: 'Koʻrdim. Mahsulotda qanday muammo bor?',
    ),
    demoMessage(
      id++,
      minutesAgo: 25,
      mine: true,
      content: 'Qadoq yirtilgan holda keldi.',
      attachments: [
        for (final seed in ['box1', 'box2', 'box3', 'box4', 'box5'])
          _image(seed),
      ],
    ),
    demoMessage(
      id++,
      minutesAgo: 24,
      content: 'Shu rasmdagi kabi qadoqmi?',
      attachments: [_image('package')],
    ),
    demoMessage(
      id++,
      minutesAgo: 23,
      mine: true,
      content: 'Ha, xuddi shunday.',
    ),
    demoMessage(
      id++,
      minutesAgo: 22,
      content: null,
      attachments: [
        _attachment('file', 'https://example.com/files/ariza-4821.pdf', 184320),
      ],
    ),
    demoMessage(
      id++,
      minutesAgo: 20,
      mine: true,
      content: null,
      attachments: [_attachment('audio', _sampleAudio, 40960)],
    ),
    demoMessage(
      id++,
      minutesAgo: 19,
      content:
          'Uzr soʻraymiz. Almashtirish uchun ariza ochdim — kuryer ertaga '
          '10:00–13:00 oraligʻida olib ketadi.',
    ),
  ];
}
