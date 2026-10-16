import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/shared/wav.dart';

void main() {
  test('wavFromPcm16 writes a 44-byte header', () {
    final wav = wavFromPcm16(Uint8List(10), sampleRate: 16000);
    final data = ByteData.sublistView(wav);

    expect(wav.length, 54);
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(data.getUint32(24, Endian.little), 16000);
    expect(data.getUint32(40, Endian.little), 10);
  });

  test('the recorder header (16 kHz mono PCM16) parses to the real length', () {
    final pcm = Uint8List(16000 * 2 * 3); // 3 s
    expect(
      wavDuration(wavFromPcm16(pcm, sampleRate: 16000)),
      const Duration(seconds: 3),
    );
  });

  test('placeholder data sizes give null, not a made-up length', () {
    final wav = wavFromPcm16(Uint8List(64), sampleRate: 16000);
    ByteData.sublistView(wav).setUint32(40, 0xFFFFFFFF, Endian.little);
    expect(wavDuration(wav), isNull);
    ByteData.sublistView(wav).setUint32(40, 0, Endian.little);
    expect(wavDuration(wav), isNull);
  });

  test('not a WAV gives null', () {
    expect(wavDuration(Uint8List.fromList(List.filled(64, 1))), isNull);
  });
}
