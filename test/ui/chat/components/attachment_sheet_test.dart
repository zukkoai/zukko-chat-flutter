import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_upload.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';
import 'package:zukko_chat_flutter/src/ui/chat/zukko_chat_style.dart';
import 'package:zukko_chat_flutter/src/ui/l10n/zukko_chat_l10n.dart';
import 'package:zukko_chat_flutter/src/ui/theme/zukko_chat_theme.dart';

final _skipGolden = Platform.isMacOS ? null : 'goldens are generated on macOS';
const _l10n = ZukkoChatL10n.uzLatn;
const _max = ZukkoChatUpload.maxSizeMb;

class _Result {
  bool done = false;
  AttachmentSource? source;
}

Future<_Result> _open(
  WidgetTester tester,
  ZukkoChatStyle style,
  Brightness brightness, {
  Size size = const Size(390, 844),
  double textScale = 1,
  ZukkoChatL10n l10n = _l10n,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = style.resolve(ZukkoChatTheme(brightness: brightness));
  final result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: s.backgroundColor,
          body: Center(
            child: TextButton(
              onPressed: () async {
                result.source = await showAttachmentSourceSheet(
                  context,
                  l10n: l10n,
                  spec: s.attachSheet,
                  maxMb: _max,
                );
                result.done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  for (final style in ZukkoChatStyle.values) {
    group(style.name, () {
      final hasCancel =
          style == ZukkoChatStyle.smoothSilk ||
          style == ZukkoChatStyle.minimalClean;

      testWidgets('shows title, two side-by-side options, limit', (t) async {
        await _open(t, style, Brightness.light);
        expect(find.text(_l10n.attachImageLabel), findsOneWidget);
        expect(find.text(_l10n.attachFileLabel), findsOneWidget);
        final title = style == ZukkoChatStyle.minimalClean
            ? _l10n.attachSheetTitleWithLimit(_max)
            : _l10n.attachSheetTitle;
        expect(find.text(title), findsOneWidget);
        if (style != ZukkoChatStyle.minimalClean) {
          expect(find.text(_l10n.attachLimitNote(_max)), findsOneWidget);
        }
        expect(_l10n.attachLimitNote(_max), contains('$_max'));
        expect(
          find.text(_l10n.cancelLabel),
          hasCancel ? findsOneWidget : findsNothing,
        );
        final image = t.getCenter(find.text(_l10n.attachImageLabel));
        final file = t.getCenter(find.text(_l10n.attachFileLabel));
        if (style == ZukkoChatStyle.minimalClean) {
          expect(file.dy, greaterThan(image.dy)); // stacked rows
        } else {
          expect(file.dy, closeTo(image.dy, 1)); // side by side
          expect(file.dx, greaterThan(image.dx));
        }
      });

      testWidgets('tapping photo returns image', (t) async {
        final r = await _open(t, style, Brightness.light);
        await t.tap(find.text(_l10n.attachImageLabel));
        await t.pumpAndSettle();
        expect(r.done, isTrue);
        expect(r.source, AttachmentSource.image);
      });

      testWidgets('tapping file returns file', (t) async {
        final r = await _open(t, style, Brightness.light);
        await t.tap(find.text(_l10n.attachFileLabel));
        await t.pumpAndSettle();
        expect(r.source, AttachmentSource.file);
      });

      testWidgets('cancel / close returns null', (t) async {
        final r = await _open(t, style, Brightness.light);
        if (hasCancel) {
          await t.tap(find.text(_l10n.cancelLabel));
        } else {
          await t.tap(find.bySemanticsLabel(_l10n.closeLabel));
        }
        await t.pumpAndSettle();
        expect(r.done, isTrue);
        expect(r.source, isNull);
      });

      testWidgets('tapping the scrim dismisses with null', (t) async {
        final r = await _open(t, style, Brightness.light);
        await t.tapAt(const Offset(195, 20));
        await t.pumpAndSettle();
        expect(r.done, isTrue);
        expect(r.source, isNull);
      });

      testWidgets('options are at least 48 dp tall', (t) async {
        await _open(t, style, Brightness.light);
        for (final label in [_l10n.attachImageLabel, _l10n.attachFileLabel]) {
          final box = find.ancestor(
            of: find.text(label),
            matching: find.byType(InkWell),
          );
          expect(t.getSize(box.first).height, greaterThanOrEqualTo(48));
        }
      });

      for (final scale in [1.3, 2.0]) {
        testWidgets('320 dp wide, text x$scale: no overflow', (t) async {
          await _open(
            t,
            style,
            Brightness.dark,
            size: const Size(320, 640),
            textScale: scale,
          );
          expect(t.takeException(), isNull);
          expect(find.text(_l10n.attachImageLabel), findsOneWidget);
        });
      }

      for (final b in Brightness.values) {
        testWidgets('golden ${b.name}', (t) async {
          await _open(t, style, b);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/attach_sheet_${style.name}_${b.name}.png',
            ),
          );
        }, skip: _skipGolden != null);
      }
    });
  }
}
