import 'dart:io';
import 'dart:typed_data';

import 'package:zukko_chat_flutter/src/core/zukko_chat_upload.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/message_body.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
  final png = ZukkoChatUpload.bytes(name: 'a.png', bytes: Uint8List(3));

  Map<String, String> fields(FormData form) => {
    for (final e in form.fields) e.key: e.value,
  };

  group('buildMessageJson', () {
    test('has exact keys and utc timestamp, no reply_to by default', () {
      final m =
          buildMessageJson(content: 'hi', echoId: 'e1', now: now)['message']
              as Map;
      expect(m, {
        'content': 'hi',
        'referer_url': '',
        'timestamp': '2026-01-02T03:04:05.000Z',
        'echo_id': 'e1',
      });
    });

    test('reply_to only when set', () {
      final m =
          buildMessageJson(content: 'hi', echoId: 'e1', replyTo: 7)['message']
              as Map;
      expect(m['reply_to'], 7);
    });
  });

  group('buildMessageForm', () {
    test('field names, referer_url always present, no reply_to', () async {
      final f = await buildMessageForm(
        content: 'hi',
        echoId: 'e1',
        files: [png],
        now: now,
      );
      expect(fields(f), {
        'message[content]': 'hi',
        'message[referer_url]': '',
        'message[timestamp]': '2026-01-02T03:04:05.000Z',
        'message[echo_id]': 'e1',
      });
    });

    test('empty content omitted, reply_to included when set', () async {
      final f = await buildMessageForm(
        content: '',
        echoId: 'e1',
        files: [png],
        replyTo: 9,
      );
      final m = fields(f);
      expect(m.containsKey('message[content]'), isFalse);
      expect(m['message[reply_to]'], '9');
      expect(m['message[referer_url]'], '');
    });

    test('bytes file: key, filename, content type', () async {
      final f = await buildMessageForm(content: 'x', echoId: 'e', files: [png]);
      expect(f.files.single.key, 'message[attachments][]');
      expect(f.files.single.value.filename, 'a.png');
      expect(f.files.single.value.contentType?.mimeType, 'image/png');
      expect(f.files.single.value.length, 3);
    });

    test(
      'path file: filename from name, content type from extension',
      () async {
        final dir = Directory.systemTemp.createTempSync();
        addTearDown(() => dir.deleteSync(recursive: true));
        final p = File('${dir.path}/blob')..writeAsBytesSync([1, 2]);
        final up = ZukkoChatUpload.file(name: 'doc.pdf', path: p.path);
        final f = await buildMessageForm(content: '', echoId: 'e', files: [up]);
        expect(f.files.single.value.filename, 'doc.pdf');
        expect(f.files.single.value.contentType?.mimeType, 'application/pdf');
        expect(f.files.single.value.length, 2);
      },
    );

    test('clone() gives an equal, reusable form', () async {
      final f = await buildMessageForm(
        content: 'hi',
        echoId: 'e',
        files: [png],
        now: now,
      );
      final c = f.clone();
      expect(fields(c), fields(f));
      expect(c.files.single.key, 'message[attachments][]');
      expect(c.files.single.value.filename, 'a.png');
      expect(c.files.single.value.length, 3);
      expect(c.clone().files.length, 1);
    });
  });
}
