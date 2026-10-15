import 'dart:io';

import 'package:zukko_chat_flutter/src/ui/chat/styles/minimal_clean/minimal_clean_tokens.dart';
import 'package:zukko_chat_flutter/src/ui/chat/styles/smooth_silk/smooth_silk_tokens.dart';
import 'package:zukko_chat_flutter/src/ui/chat/styles/thread_feed/thread_feed_tokens.dart';
import 'package:zukko_chat_flutter/src/ui/theme/chatwoot_chat_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const light = ZukkoChatTheme(brightness: Brightness.light);
  const forced = ZukkoChatTheme(
    brightness: Brightness.light,
    fontFamily: 'Custom',
  );

  test('each style uses its bundled package font', () {
    expect(
      SmoothSilkTokens.from(light).body.fontFamily,
      'packages/zukko_chat_flutter/Manrope',
    );
    expect(
      MinimalCleanTokens.from(light).body.fontFamily,
      'packages/zukko_chat_flutter/Geist',
    );
    expect(
      ThreadFeedTokens.from(light).bodyStrong.fontFamily,
      'packages/zukko_chat_flutter/Onest',
    );
  });

  test('ZukkoChatTheme.fontFamily still overrides', () {
    expect(SmoothSilkTokens.from(forced).body.fontFamily, 'Custom');
    expect(MinimalCleanTokens.from(forced).body.fontFamily, 'Custom');
    expect(ThreadFeedTokens.from(forced).body.fontFamily, 'Custom');
  });

  test('declared font assets and licenses exist on disk', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assets = RegExp(r'asset: (\S+)')
        .allMatches(pubspec)
        .map((m) => m[1]!);
    expect(assets, hasLength(6));
    for (final a in assets) {
      expect(File(a).existsSync(), isTrue, reason: a);
    }
    for (final d in ['manrope', 'geist', 'onest']) {
      expect(File('assets/fonts/$d/OFL.txt').existsSync(), isTrue, reason: d);
    }
  });
}
