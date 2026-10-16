import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_upload.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_upload_policy.dart';

void main() {
  Future<void> ok(String name) =>
      validateUpload(ZukkoChatUpload.bytes(name: name, bytes: Uint8List(1)));
  final rejects = throwsA(
    isA<ZukkoChatException>().having(
      (e) => e.type,
      'type',
      ZukkoChatExceptionType.sendMessageFailed,
    ),
  );

  test('accepts media and listed documents', () async {
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
      await ok(n);
    }
  });

  test('rejects unlisted or unknown types', () async {
    for (final n in ['a.exe', 'a.html', 'a.js', 'noext', 'a.unknownext']) {
      await expectLater(ok(n), rejects, reason: n);
    }
  });

  test('size boundary: 40 MB ok, one byte more rejected', () async {
    await validateUpload(
      const ZukkoChatUpload.file(
        name: 'a.png',
        path: '/x',
        size: ZukkoChatUpload.maxSize,
      ),
    );
    await expectLater(
      validateUpload(
        const ZukkoChatUpload.file(
          name: 'a.png',
          path: '/x',
          size: ZukkoChatUpload.maxSize + 1,
        ),
      ),
      rejects,
    );
  });

  test('the size message names the limit from one place (D9)', () async {
    await expectLater(
      validateUpload(
        const ZukkoChatUpload.file(
          name: 'a.png',
          path: '/x',
          size: ZukkoChatUpload.maxSize + 1,
        ),
      ),
      throwsA(
        isA<ZukkoChatException>().having(
          (e) => e.cause,
          'cause',
          contains('${ZukkoChatUpload.maxSizeMb} MB'),
        ),
      ),
    );
  });

  test('upload helpers agree with the policy', () {
    final video = ZukkoChatUpload.bytes(name: 'a.mp4', bytes: Uint8List(1));
    expect([video.isVideo, video.isImage, video.isAudio], [true, false, false]);
    expect(video.mediaType?.mimeType, 'video/mp4');
  });
}
