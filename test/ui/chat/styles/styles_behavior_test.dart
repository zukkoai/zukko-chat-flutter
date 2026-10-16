import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';
import 'package:zukko_chat_flutter/src/ui/chat/styles/minimal_clean/minimal_clean_tokens.dart';
import 'package:zukko_chat_flutter/src/ui/chat/styles/smooth_silk/smooth_silk_tokens.dart';
import 'package:zukko_chat_flutter/src/ui/chat/styles/thread_feed/thread_feed_tokens.dart';
import 'package:zukko_chat_flutter/src/ui/chat/zukko_chat_style.dart';
import 'package:zukko_chat_flutter/src/ui/l10n/zukko_chat_l10n.dart';
import 'package:zukko_chat_flutter/src/ui/theme/chat_base_tokens.dart';
import 'package:zukko_chat_flutter/src/ui/theme/zukko_chat_theme.dart';

import 'styles_harness.dart';

const _l10n = ZukkoChatL10n();

Widget _host(Widget child, {TextScaler scaler = TextScaler.noScaling}) =>
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: scaler),
          child: child,
        ),
      ),
    );

Widget _composer(ChatStyle style, {VoidCallback? onTyping}) => Builder(
  builder: (context) => style.buildComposer(
    context,
    ChatComposerData(
      onSend: (_) {},
      onTyping: onTyping,
      onAttach: () {},
      onVoiceRecorded: (_) {},
    ),
    _l10n,
  ),
);

/// A fake microphone so a recorder can really be "recording".
class _FakeCapture implements VoiceCapture {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async =>
      const Stream.empty();

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  for (final styleKind in ZukkoChatStyle.values) {
    group(styleKind.name, () {
      const theme = ZukkoChatTheme(brightness: Brightness.light);
      final style = styleKind.resolve(theme);

      testWidgets('the unsupported-message text uses the style body look', (
        tester,
      ) async {
        final b = style.messageBuilders(chatEnv());
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (c) => b.unsupportedMessageBuilder!(
                c,
                UnsupportedMessage(id: 'u', authorId: 'agent'),
                0,
                isSentByMe: false,
              ),
            ),
          ),
        );
        final text = tester.widget<Text>(
          find.text(_l10n.unsupportedMessageText),
        );
        expect(text.style, isNotNull);
        expect(text.style!.fontSize, isNotNull);
      });

      testWidgets('media never overflows a 320 dp screen (S14)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final b = style.messageBuilders(chatEnv());
        final image = ImageMessage(id: 'i', authorId: 'agent', source: '');
        final gallery = GalleryMessage.create(
          id: 'g',
          authorId: 'agent',
          images: List.filled(4, ''),
        );
        await tester.pumpWidget(
          _host(
            SingleChildScrollView(
              child: Column(
                children: [
                  messageOf(b, image, false),
                  messageOf(b, gallery, false),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        // The width the style asks for is the width the media gets (a wider
        // ask is clamped by the parent and the grid would lay out for the
        // wrong width).
        final img = find.byType(ChatImage).first;
        expect(tester.widget<ChatImage>(img).width, tester.getSize(img).width);
        final grid = find.byType(ImageGrid);
        expect(
          tester.widget<ImageGrid>(grid).width,
          tester.getSize(grid).width,
        );
      });

      testWidgets(
        'a zero horizontal padding does not break the composer (S15)',
        (tester) async {
          final s = styleKind.resolve(
            const ZukkoChatTheme(
              brightness: Brightness.light,
              horizontalPadding: 0,
            ),
          );
          await tester.pumpWidget(_host(_composer(s)));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('buttons are at least 48 dp (S20)', (tester) async {
        await tester.pumpWidget(_host(_composer(style)));
        for (final label in [_l10n.attachLabel, _l10n.sendLabel]) {
          final size = tester.getSize(find.byTooltip(label));
          expect(size.width, greaterThanOrEqualTo(48), reason: label);
          expect(size.height, greaterThanOrEqualTo(48), reason: label);
        }
        final mic = tester.getSize(find.byType(VoiceRecordButton));
        expect(mic.shortestSide, greaterThanOrEqualTo(48));
      });

      testWidgets('the title is a header, the status a live region (S21)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => style.buildHeader(
                context,
                const ChatHeaderData(
                  title: 'Zukko Support',
                  status: 'Online',
                  isOnline: true,
                ),
                _l10n,
              ),
            ),
          ),
        );
        expect(
          tester.getSemantics(find.text('Zukko Support')),
          isSemantics(isHeader: true),
        );
        expect(
          tester.getSemantics(find.text('Online')),
          isSemantics(isLiveRegion: true),
        );
        handle.dispose();
      });

      testWidgets('a failed message says so, as a live region (S21)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final b = style.messageBuilders(chatEnv());
        await tester.pumpWidget(
          _host(
            messageOf(
              b,
              TextMessage(
                id: 'f',
                authorId: 'me',
                text: 'oops',
                status: MessageStatus.error,
              ),
              true,
            ),
          ),
        );
        expect(
          tester.getSemantics(find.text(_l10n.messageFailedHint)),
          isSemantics(isLiveRegion: true),
        );
        handle.dispose();
      });

      testWidgets('typing fires on edits, not on caret moves (U24)', (
        tester,
      ) async {
        var typing = 0;
        await tester.pumpWidget(
          _host(_composer(style, onTyping: () => typing++)),
        );
        await tester.enterText(find.byType(TextField), 'hello');
        expect(typing, 1);
        final field = tester.widget<TextField>(find.byType(TextField));
        field.controller!.selection = const TextSelection.collapsed(offset: 2);
        await tester.pump();
        expect(typing, 1);
        await tester.enterText(find.byType(TextField), 'hello!');
        expect(typing, 2);
      });

      testWidgets('sending shows a clock with a label; sent does not', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final b = style.messageBuilders(chatEnv());
        Future<void> show(MessageStatus? status) => tester.pumpWidget(
          _host(
            messageOf(
              b,
              TextMessage(
                id: 's',
                authorId: 'me',
                text: 'wait',
                createdAt: sampleTime,
                status: status,
              ),
              true,
            ),
          ),
        );
        await show(MessageStatus.sending);
        expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
        expect(
          find.bySemanticsLabel(_l10n.messageSendingLabel),
          findsOneWidget,
        );
        await show(MessageStatus.sent);
        expect(find.byIcon(Icons.schedule_rounded), findsNothing);
        await show(MessageStatus.delivered);
        expect(find.byIcon(Icons.schedule_rounded), findsNothing);
        handle.dispose();
      });

      testWidgets('a failed message reads "Not sent. Tap to retry"', (
        tester,
      ) async {
        final b = style.messageBuilders(chatEnv());
        await tester.pumpWidget(
          _host(
            messageOf(
              b,
              TextMessage(
                id: 'f',
                authorId: 'me',
                text: 'x',
                status: MessageStatus.error,
              ),
              true,
            ),
          ),
        );
        expect(find.text('Not sent. Tap to retry'), findsOneWidget);
        expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      });

      testWidgets('the sending message is dimmed', (tester) async {
        final b = style.messageBuilders(chatEnv());
        await tester.pumpWidget(
          _host(
            messageOf(
              b,
              TextMessage(
                id: 's',
                authorId: 'me',
                text: 'wait',
                status: MessageStatus.sending,
              ),
              true,
            ),
          ),
        );
        expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.6);
      });
    });
  }

  testWidgets('Minimal Clean shows the time of a message (S19)', (
    tester,
  ) async {
    final style = ZukkoChatStyle.minimalClean.resolve(
      const ZukkoChatTheme(brightness: Brightness.light),
    );
    final b = style.messageBuilders(chatEnv());
    await tester.pumpWidget(
      _host(
        messageOf(
          b,
          TextMessage(
            id: 't',
            authorId: 'agent',
            text: 'hi',
            createdAt: sampleTime,
          ),
          false,
        ),
      ),
    );
    final time = DateFormat('HH:mm').format(sampleTime.toLocal());
    expect(find.text(time), findsOneWidget);
  });

  testWidgets('the recording bar grows with the text scale (S21)', (
    tester,
  ) async {
    final recorder = VoiceRecorderController(
      onRecorded: (_) {},
      onIssue: (_) {},
      capture: _FakeCapture.new,
    );
    addTearDown(recorder.dispose);
    await recorder.start();
    expect(recorder.isRecording, isTrue);
    final tokens = SmoothSilkTokens.from(
      const ZukkoChatTheme(brightness: Brightness.light),
    );
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 300,
          child: ComposerInput(
            handle: ComposerHandle(
              text: TextEditingController(),
              focusNode: FocusNode(),
              canSend: false,
              send: () {},
              recorder: recorder,
            ),
            l10n: _l10n,
            tokens: tokens,
            minHeight: 48,
          ),
        ),
        scaler: const TextScaler.linear(3),
      ),
    );
    expect(tester.takeException(), isNull);
    final bar = tester.getSize(find.byType(VoiceRecordingBar));
    final timer = tester.getSize(find.textContaining('0:'));
    expect(bar.height, greaterThanOrEqualTo(48));
    expect(bar.height, greaterThanOrEqualTo(timer.height));
    await recorder.cancel();
  });

  group('tokens follow the app overrides (S16)', () {
    const light = ZukkoChatTheme(brightness: Brightness.light);
    const brand = Color(0xFF7B1FA2);
    const paper = Color(0xFFFFF8E1);

    test('Thread Feed: the mic tile is a wash of the accent', () {
      final plain = ThreadFeedTokens.from(light);
      final branded = ThreadFeedTokens.from(light.copyWith(accentColor: brand));
      expect(branded.micFill, isNot(plain.micFill));
      expect(branded.micIcon, brand);
    });

    test('Smooth Silk: the attach disc is the background', () {
      final t = SmoothSilkTokens.from(light.copyWith(backgroundColor: paper));
      expect(t.composerButtonFill, paper);
    });

    test('Minimal Clean: composer and bubbles leave the background', () {
      final t = MinimalCleanTokens.from(light.copyWith(backgroundColor: paper));
      expect(t.composerFill, paper);
      expect(t.outgoingBubble, isNot(paper));
      expect(t.composerBorder, isNot(paper));
    });

    test('defaults are unchanged without an override', () {
      expect(
        SmoothSilkTokens.from(light).composerButtonFill,
        const Color(0xFFEDF0F4),
      );
      expect(ThreadFeedTokens.from(light).micFill, const Color(0xFFE1EEEC));
      expect(
        MinimalCleanTokens.from(light).composerFill,
        const Color(0xFFFFFFFF),
      );
    });

    test('tint is a step toward the text color', () {
      expect(
        ChatBaseTokens.tint(
          const Color(0xFFFFFFFF),
          const Color(0xFF000000),
          0,
        ),
        const Color(0xFFFFFFFF),
      );
    });
  });

  test('composerInsets never goes negative (S15)', () {
    expect(composerInsets(0, shave: 4, top: 1, bottom: 2).left, 0);
    expect(composerInsets(16, shave: 4, top: 1, bottom: 2).left, 12);
  });
}
