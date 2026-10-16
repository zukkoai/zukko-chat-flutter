import 'dart:typed_data';

/// [pcm] (16-bit little-endian) wrapped in a WAV header.
Uint8List wavFromPcm16(
  Uint8List pcm, {
  required int sampleRate,
  int channels = 1,
}) {
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final header = ByteData(44)
    ..setUint32(0, 0x52494646) // "RIFF"
    ..setUint32(4, 36 + pcm.length, Endian.little)
    ..setUint32(8, 0x57415645) // "WAVE"
    ..setUint32(12, 0x666d7420) // "fmt "
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, channels * bitsPerSample ~/ 8, Endian.little)
    ..setUint16(34, bitsPerSample, Endian.little)
    ..setUint32(36, 0x64617461) // "data"
    ..setUint32(40, pcm.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm))
      .takeBytes();
}

/// Length of the PCM WAV whose first bytes are [head] (header chunks up to
/// and including the `data` chunk size); null when it is not a PCM WAV or the
/// sizes are placeholders (0 / 0xFFFFFFFF, written by streaming encoders).
Duration? wavDuration(Uint8List head) {
  if (head.length < 12) return null;
  final d = ByteData.sublistView(head);
  if (d.getUint32(0) != 0x52494646 || d.getUint32(8) != 0x57415645) {
    return null;
  }
  var byteRate = 0;
  var offset = 12;
  while (offset + 8 <= head.length) {
    final id = d.getUint32(offset);
    final size = d.getUint32(offset + 4, Endian.little);
    if (id == 0x666d7420) {
      // "fmt "
      if (offset + 8 + 12 > head.length) return null;
      byteRate = d.getUint32(offset + 16, Endian.little);
    } else if (id == 0x64617461) {
      // "data"
      if (byteRate <= 0 || size == 0 || size == 0xFFFFFFFF) return null;
      return Duration(
        microseconds: size * Duration.microsecondsPerSecond ~/ byteRate,
      );
    }
    offset += 8 + size + (size & 1);
  }
  return null;
}
