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
}
