import 'dart:io';
import 'dart:typed_data';

import 'package:chatwoot_sdk/src/core/chatwoot_client_exception.dart';
import 'package:chatwoot_sdk/src/core/chatwoot_upload.dart';
import 'package:chatwoot_sdk/src/data/remote/api/widget_message_form.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
  final png = ChatwootUpload.bytes(name: 'a.png', bytes: Uint8List(3));

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
        final up = ChatwootUpload.file(name: 'doc.pdf', path: p.path);
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

  group('validateUpload', () {
    void ok(String name) => expect(
      () =>
          validateUpload(ChatwootUpload.bytes(name: name, bytes: Uint8List(1))),
      returnsNormally,
    );
    void bad(String name) => expect(
      () =>
          validateUpload(ChatwootUpload.bytes(name: name, bytes: Uint8List(1))),
      throwsA(
        isA<ChatwootClientException>().having(
          (e) => e.type,
          'type',
          ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
        ),
      ),
    );

    test('accepts media and listed documents', () {
      for (final n in [
        'a.png',
        'a.jpg',
        'a.mp4',
        'a.mp3',
        'a.wav',
        'a.pdf',
        'a.txt',
        'a.csv',
        'a.zip',
        'a.docx',
        'a.xlsx',
        'a.json',
      ]) {
        ok(n);
      }
    });

    test('rejects unlisted or unknown types', () {
      for (final n in ['a.exe', 'a.html', 'a.js', 'noext', 'a.unknownext']) {
        bad(n);
      }
    });

    test('size boundary: 40 MB ok, one byte more rejected', () {
      ok('a.png');
      expect(
        () => validateUpload(
          ChatwootUpload.file(
            name: 'a.png',
            path: '/x',
            size: ChatwootUpload.maxSize,
          ),
        ),
        returnsNormally,
      );
      expect(
        () => validateUpload(
          ChatwootUpload.file(
            name: 'a.png',
            path: '/x',
            size: ChatwootUpload.maxSize + 1,
          ),
        ),
        throwsA(isA<ChatwootClientException>()),
      );
    });
  });
}
