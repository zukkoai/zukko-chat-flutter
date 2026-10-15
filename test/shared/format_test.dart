import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/shared/format.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 9)), '0:09');
    expect(formatDuration(const Duration(minutes: 12, seconds: 30)), '12:30');
  });

  test('formatBytes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(12 * 1024 * 1024), '12 MB');
  });
}
