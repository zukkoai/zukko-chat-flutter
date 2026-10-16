import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/chat_message_mapper.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/gallery_message.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

import 'chat_fakes.dart';

Map<String, dynamic> _att(String type, String url) => {
  'file_type': type,
  'data_url': url,
  'file_size': 10,
};

void main() {
  final mapper = ChatMessageMapper(const ZukkoChatL10n());

  Message? map(ZukkoChatMessage m) =>
      mapper.fromServer(m, key: m.id.toString())?.message;

  test('activity and template lines are hidden (same rule as the model)', () {
    expect(map(msg(1, type: 2)), isNull);
    expect(map(msg(2, type: 3)), isNull);
    expect(map(msg(3, type: 1)), isA<TextMessage>());
  });

  test('empty text without attachments is hidden', () {
    expect(map(msg(1, content: '  ')), isNull);
  });

  test('agent author comes back with an https avatar only', () {
    final ok = mapper.fromServer(
      msg(
        1,
        sender: const ZukkoChatEventMessageUser(
          id: 5,
          name: 'Ann',
          avatarUrl: 'https://cdn.test/a.png',
        ),
      ),
      key: '1',
    )!;
    expect(ok.author!.id, 'agent:5');
    expect(ok.author!.imageSource, 'https://cdn.test/a.png');

    final http = mapper.fromServer(
      msg(
        2,
        sender: const ZukkoChatEventMessageUser(
          id: 5,
          name: 'Ann',
          avatarUrl: 'http://cdn.test/a.png',
        ),
      ),
      key: '2',
    )!;
    expect(http.author!.imageSource, isNull);
  });

  test('attachments: one image, gallery, audio, file; http is dropped', () {
    expect(
      map(
        msg(1, content: null, attachments: [_att('image', 'https://c/a.jpg')]),
      ),
      isA<ImageMessage>(),
    );
    final gallery = map(
      msg(
        2,
        content: null,
        attachments: [
          _att('image', 'https://c/a.jpg'),
          _att('image', 'https://c/b.jpg'),
        ],
      ),
    )!;
    expect(GalleryMessage.imagesOf(gallery), hasLength(2));
    expect(
      map(
        msg(3, content: null, attachments: [_att('audio', 'https://c/a.wav')]),
      ),
      isA<AudioMessage>(),
    );
    expect(
      map(
        msg(4, content: null, attachments: [_att('file', 'https://c/a.pdf')]),
      ),
      isA<FileMessage>(),
    );
    // an http attachment is ignored: falls back to the attachment label
    final fallback = map(
      msg(5, content: null, attachments: [_att('image', 'http://c/a.jpg')]),
    ) as TextMessage;
    expect(fallback.text, 'Attachment');
  });

  test('own messages are seen; unparsable date uses the fallback', () {
    final fallback = DateTime.utc(2020, 1, 1);
    final m = mapper
        .fromServer(
          msg(1, type: 0, createdAt: 'garbage'),
          key: '1',
          fallbackCreatedAt: fallback,
        )!
        .message;
    expect(m.authorId, chatMeId);
    expect(m.status, MessageStatus.seen);
    expect(m.createdAt, fallback);
  });
}
