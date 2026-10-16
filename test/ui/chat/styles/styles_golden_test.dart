import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/zukko_chat_style.dart';

import 'styles_harness.dart';

import 'package:zukko_chat_flutter/src/ui/l10n/zukko_chat_l10n.dart';
import 'package:zukko_chat_flutter/src/ui/theme/zukko_chat_theme.dart';

/// Pixel snapshots of the three looks (light + dark) so shared-builder
/// refactors cannot change them silently. Goldens are rendered on macOS; on
/// other platforms the font rasterisation differs, so they are skipped there.
final _skip = Platform.isMacOS ? null : 'goldens are generated on macOS';

void main() {
  for (final style in ZukkoChatStyle.values) {
    for (final brightness in Brightness.values) {
      final name = '${style.name}_${brightness.name}';
      final theme = ZukkoChatTheme(brightness: brightness);

      testWidgets('$name messages', (tester) async {
        tester.view.physicalSize = const Size(390, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final s = style.resolve(theme);
        final b = s.messageBuilders(chatEnv());
        final msgs = sampleMessages();
        await tester.pumpWidget(
          frame(
            ThemeData(brightness: brightness),
            s.backgroundColor,
            SingleChildScrollView(
              child: Column(
                children: [
                  for (final m in msgs) messageOf(b, m, m.authorId == 'me'),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byKey(const ValueKey('shot')),
          matchesGoldenFile('goldens/${name}_messages.png'),
        );
      }, skip: _skip != null);

      testWidgets('$name chrome', (tester) async {
        tester.view.physicalSize = const Size(390, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final s = style.resolve(theme);
        const l10n = ZukkoChatL10n();
        await tester.pumpWidget(
          frame(
            ThemeData(brightness: brightness),
            s.backgroundColor,
            Builder(
              builder: (context) => Column(
                children: [
                  s.buildHeader(
                    context,
                    ChatHeaderData(
                      title: 'Zukko Support',
                      status: 'Online',
                      isOnline: true,
                      onBack: () {},
                      onMore: () {},
                    ),
                    l10n,
                  ),
                  const Spacer(),
                  s.buildTypingIndicator(context, l10n),
                  s.buildComposer(
                    context,
                    ChatComposerData(
                      onSend: (_) {},
                      onAttach: () {},
                      onVoiceRecorded: (_) {},
                    ),
                    l10n,
                  ),
                  s.buildFooter(context, l10n),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await expectLater(
          find.byKey(const ValueKey('shot')),
          matchesGoldenFile('goldens/${name}_chrome.png'),
        );
      }, skip: _skip != null);
    }
  }
}
