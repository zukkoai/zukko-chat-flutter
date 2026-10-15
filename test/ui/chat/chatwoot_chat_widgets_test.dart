import 'dart:async';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/src/ui/chat/chatwoot_chat_view.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'chat_fakes.dart';

const _o = ChatwootChatOptions(
  baseUrl: 'https://x.test',
  inboxIdentifier: 'in',
);

Widget _app(
  Widget home, {
  ThemeData? theme,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  theme: theme,
  builder: (context, child) =>
      Directionality(textDirection: dir, child: child!),
  home: home,
);

/// The colour the chat view paints behind everything.
Color _background(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(ChatwootChatView),
            matching: find.byType(ColoredBox),
          )
          .first,
    )
    .color;

/// pumpWidget + enough time for the chat list's short internal timers.
Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Runs queued microtasks and the list's insert animations on the fake
/// clock (no real waiting).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  late FakeFactory factory;
  late FakeClient client;

  // The style fonts come from google_fonts; no network in tests.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    factory = FakeFactory();
    client = FakeClient();
  });

  group('page', () {
    testWidgets('typing and sending before the client exists is queued (U4)', (
      tester,
    ) async {
      await _pump(
        tester,
        _app(ChatwootChat(options: _o, clientFactory: factory.call)),
      );
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      await _settle(tester);
      expect(find.text('hello', findRichText: true), findsOneWidget);
      expect(client.sent, isEmpty);

      factory.completer.complete(client);
      await _settle(tester);

      expect(client.sent.single.content, 'hello');
    });

    testWidgets('leaving the page before the client exists disposes it (U3)', (
      tester,
    ) async {
      final errors = <ChatwootClientException>[];
      await _pump(
        tester,
        _app(
          ChatwootChat(
            options: _o,
            callbacks: ChatwootCallbacks(onError: errors.add),
            clientFactory: factory.call,
          ),
        ),
      );
      await _pump(tester, _app(const SizedBox()));

      factory.completer.complete(client);
      await _settle(tester);

      expect(factory.calls, 1);
      expect(client.disposed, isTrue);
      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a server message shows up, activity messages do not', (
      tester,
    ) async {
      factory.completer.complete(client);
      await _pump(
        tester,
        _app(ChatwootChat(options: _o, clientFactory: factory.call)),
      );
      await tester.pump();

      factory.callbacks!.onMessageReceived!(msg(1, content: 'from agent'));
      factory.callbacks!.onMessageReceived!(
        msg(2, content: 'assigned', type: 2),
      );
      await _settle(tester);

      expect(find.text('from agent', findRichText: true), findsOneWidget);
      expect(find.text('assigned', findRichText: true), findsNothing);
    });

    testWidgets('tapping a failed message resends it', (tester) async {
      factory.completer.complete(client);
      await _pump(
        tester,
        _app(ChatwootChat(options: _o, clientFactory: factory.call)),
      );
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'retry me');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await _settle(tester);
      factory.callbacks!.onError!(
        ChatwootClientException(
          'x',
          ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
          data: client.sent.single.echoId,
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('retry me', findRichText: true));
      await _settle(tester);

      expect(client.sent.length, 2);
    });

    testWidgets(
      'changing the server restarts the client; l10n alone does not',
      (tester) async {
        var created = 0;
        Future<ChatwootClient> f({
          required String baseUrl,
          required String inboxIdentifier,
          ChatwootUser? user,
          bool enablePersistence = true,
          bool allowInsecure = false,
          ChatwootCallbacks? callbacks,
        }) async {
          created++;
          return FakeClient();
        }

        ChatwootChat page(ChatwootChatOptions o) =>
            ChatwootChat(options: o, clientFactory: f);
        await _pump(tester, _app(page(_o)));
        await _pump(
          tester,
          _app(
            page(
              const ChatwootChatOptions(
                baseUrl: 'https://x.test',
                inboxIdentifier: 'in',
                l10n: ChatwootL10n(inputPlaceholder: 'new'),
              ),
            ),
          ),
        );
        expect(created, 1);
        expect(find.text('new'), findsOneWidget);

        await _pump(
          tester,
          _app(
            page(
              const ChatwootChatOptions(
                baseUrl: 'https://y.test',
                inboxIdentifier: 'in',
              ),
            ),
          ),
        );
        expect(created, 2);
      },
    );
  });

  group('failures and updates', () {
    testWidgets('callbacks of a rebuilt parent replace the old ones (F5)', (
      tester,
    ) async {
      final log = <String>[];
      Widget page(String name) => _app(
        ChatwootChat(
          options: _o,
          clientFactory: factory.call,
          callbacks: ChatwootCallbacks(onError: (_) => log.add(name)),
        ),
      );
      await _pump(tester, page('A'));
      await _pump(tester, page('B'));

      factory.callbacks!.onError!(
        ChatwootClientException(
          'x',
          ChatwootClientExceptionType.SOCKET_SUBSCRIPTION_REJECTED,
        ),
      );

      expect(log, ['B']);
    });

    testWidgets('start failure: message fails, error shown, retry works (F6)', (
      tester,
    ) async {
      await _pump(
        tester,
        _app(ChatwootChat(options: _o, clientFactory: factory.call)),
      );
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      factory.completer.completeError(StateError('boom'));
      await _settle(tester);

      expect(find.text('Could not connect to the chat'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      factory.completer = Completer<ChatwootClient>();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      factory.completer.complete(client);
      await _settle(tester);

      expect(factory.calls, 2);
      expect(find.text('Could not connect to the chat'), findsNothing);
    });

    testWidgets('the error banner is localised', (tester) async {
      await _pump(
        tester,
        _app(
          ChatwootChat(
            options: const ChatwootChatOptions(
              baseUrl: 'b',
              inboxIdentifier: 'i',
              l10n: ChatwootL10n(
                connectionErrorText: 'Ulanmadi',
                retryLabel: 'Qayta',
              ),
            ),
            clientFactory: factory.call,
          ),
        ),
      );
      factory.completer.completeError(StateError('boom'));
      await _settle(tester);

      expect(find.text('Ulanmadi'), findsOneWidget);
      expect(find.text('Qayta'), findsOneWidget);
    });
  });

  group('header', () {
    testWidgets('title, status and placeholder come from l10n (U5)', (
      tester,
    ) async {
      await _pump(
        tester,
        _app(
          ChatwootChat(
            title: 'Support',
            clientFactory: factory.call,
            options: const ChatwootChatOptions(
              baseUrl: 'b',
              inboxIdentifier: 'i',
              l10n: ChatwootL10n(
                inputPlaceholder: 'ZZZ',
                offlineText: 'OFFLINE!',
              ),
            ),
          ),
        ),
      );

      expect(find.text('ZZZ'), findsOneWidget);
      expect(find.text('OFFLINE!'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
    });

    testWidgets('status follows online / typing and is a live region (U12)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _app(ChatwootChat(options: _o, clientFactory: factory.call)),
      );

      factory.callbacks!.onConversationIsOnline!();
      await tester.pump();
      expect(find.text(const ChatwootL10n().onlineText), findsOneWidget);
      factory.callbacks!.onConversationStartedTyping!();
      await tester.pump();

      expect(find.text(const ChatwootL10n().typingText), findsOneWidget);
      expect(
        tester.getSemantics(find.text(const ChatwootL10n().typingText)),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('back button: shown on a pushed route, 48dp, pops it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ChatwootChat(options: _o, clientFactory: factory.call),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Back'), findsNothing);

      await tester.tap(find.text('open'));
      await _settle(tester);
      final back = find.byTooltip('Back');
      expect(back, findsOneWidget);
      final size = tester.getSize(
        find.ancestor(of: back, matching: find.byType(IconButton)),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(back),
        isSemantics(tooltip: 'Back', isButton: true, hasTapAction: true),
      );

      await tester.tap(back);
      await _settle(tester);
      expect(find.byType(ChatwootChat), findsNothing);
      handle.dispose();
    });

    testWidgets('header mirrors in RTL (U13)', (tester) async {
      Future<double> titleX(TextDirection dir) async {
        await _pump(
          tester,
          _app(
            ChatwootChat(
              title: 'Title',
              options: _o,
              clientFactory: factory.call,
            ),
            dir: dir,
          ),
        );
        final center = tester.getCenter(find.byType(ChatwootChat)).dx;
        return tester.getCenter(find.text('Title')).dx - center;
      }

      expect(await titleX(TextDirection.ltr), lessThan(0));
      expect(await titleX(TextDirection.rtl), greaterThan(0));
    });
  });

  group('branding and theme', () {
    testWidgets('footer is shown by default and comes from l10n (U10)', (
      tester,
    ) async {
      await _pump(
        tester,
        _app(
          ChatwootChat(
            options: const ChatwootChatOptions(
              baseUrl: 'b',
              inboxIdentifier: 'i',
              l10n: ChatwootL10n(poweredByText: 'Quvvat: X'),
            ),
            clientFactory: factory.call,
          ),
        ),
      );

      expect(find.text('Quvvat: X'), findsOneWidget);
      expect(find.text('Powered by Chatwoot'), findsNothing);
    });

    testWidgets('showBranding: false hides the footer (U10)', (tester) async {
      await _pump(
        tester,
        _app(
          ChatwootChat(
            options: const ChatwootChatOptions(
              baseUrl: 'b',
              inboxIdentifier: 'i',
              showBranding: false,
            ),
            clientFactory: factory.call,
          ),
        ),
      );

      expect(find.textContaining('Powered by'), findsNothing);
    });

    testWidgets('follows the ambient theme: dark differs from light (U11)', (
      tester,
    ) async {
      Future<Color?> bg(ThemeData t) async {
        await _pump(
          tester,
          _app(
            ChatwootChat(options: _o, clientFactory: factory.call),
            theme: t,
          ),
        );
        return _background(tester);
      }

      final light = await bg(ThemeData(brightness: Brightness.light));
      final dark = await bg(ThemeData(brightness: Brightness.dark));

      expect(dark, isNot(light));
      expect(dark, isNot(const Color(0xfff4f6fb)));
    });

    testWidgets('a theme registered in ThemeData.extensions is used (U11)', (
      tester,
    ) async {
      final custom = ChatwootChatTheme.fromColorScheme(
        const ColorScheme.light(),
      ).copyWith(backgroundColor: const Color(0xff123456));
      await _pump(
        tester,
        _app(
          ChatwootChat(options: _o, clientFactory: factory.call),
          theme: ThemeData(extensions: [custom]),
        ),
      );

      expect(_background(tester), const Color(0xff123456));
    });

    testWidgets('options.theme beats the extension', (tester) async {
      final explicit = ChatwootChatTheme.fromColorScheme(
        const ColorScheme.light(),
      ).copyWith(backgroundColor: const Color(0xff654321));
      await _pump(
        tester,
        _app(
          ChatwootChat(
            options: ChatwootChatOptions(
              baseUrl: 'b',
              inboxIdentifier: 'i',
              theme: explicit,
            ),
            clientFactory: factory.call,
          ),
          theme: ThemeData(
            extensions: [
              ChatwootChatTheme.fromColorScheme(const ColorScheme.dark()),
            ],
          ),
        ),
      );

      expect(_background(tester), const Color(0xff654321));
    });
  });

  group('theme value semantics (U11)', () {
    const a = ChatwootChatTheme(
      brightness: Brightness.light,
      accentColor: Color(0xff112233),
    );
    const b = ChatwootChatTheme(
      brightness: Brightness.dark,
      accentColor: Color(0xff445566),
      backgroundColor: Color(0xff000000),
    );

    test('equality, hashCode and copyWith', () {
      expect(a, const ChatwootChatTheme(
        brightness: Brightness.light,
        accentColor: Color(0xff112233),
      ));
      expect(
        ChatwootChatTheme.fromColorScheme(const ColorScheme.light()).hashCode,
        ChatwootChatTheme.fromColorScheme(const ColorScheme.light()).hashCode,
      );
      expect(a, isNot(b));
      expect(a.copyWith(), a);
      expect(a.copyWith(accentColor: Colors.pink).accentColor, Colors.pink);
      expect(a.copyWith(accentColor: Colors.pink), isNot(a));
    });

    test('lerp ends are the inputs', () {
      expect(a.lerp(b, 0).accentColor, a.accentColor);
      expect(a.lerp(b, 1).backgroundColor, b.backgroundColor);
      expect(
        a.lerp(b, 0.5).accentColor,
        Color.lerp(a.accentColor, b.accentColor, 0.5),
      );
      expect(a.lerp(null, 0.5), a);
    });
  });

  group('l10n defaults (U13)', () {
    test('online text is not the away-time copy and keys are distinct', () {
      const l = ChatwootL10n();

      expect(l.onlineText, isNot(contains('Typically')));
      expect(l.onlineText, isNot(l.offlineText));
      expect(l.conversationResolvedMessage, isNot(l.messageFailedHint));
      expect(const ChatwootL10n(), const ChatwootL10n());
      expect(const ChatwootL10n(botName: 'x'), isNot(const ChatwootL10n()));
    });
  });

  group('styles', () {
    for (final style in ChatwootChatStyle.values) {
      for (final brightness in Brightness.values) {
        testWidgets('${style.name} / ${brightness.name} renders a chat', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          factory.completer.complete(client);
          await _pump(
            tester,
            _app(
              ChatwootChat(
                title: 'Helper',
                options: ChatwootChatOptions(
                  baseUrl: 'b',
                  inboxIdentifier: 'i',
                  style: style,
                ),
                clientFactory: factory.call,
                interactions: ChatwootChatInteractions(
                  onMorePressed: () {},
                ),
              ),
              theme: ThemeData(brightness: brightness),
            ),
          );
          factory.callbacks!.onMessageReceived!(
            msg(1, content: 'see https://example.com/a'),
          );
          factory.callbacks!.onConversationStartedTyping!();
          await _settle(tester);

          expect(tester.takeException(), isNull);
          expect(find.text('Helper'), findsOneWidget);
          expect(
            find.text('see https://example.com/a', findRichText: true),
            findsOneWidget,
          );
          expect(find.text('zukko.ai'), findsOneWidget);
          expect(find.byTooltip('Attach a file or image'), findsOneWidget);
          expect(find.byTooltip('More options'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Hold to record a voice message'),
            findsOneWidget,
          );
          semantics.dispose();
        });
      }
    }

    testWidgets('attach and voice can be turned off; menu needs a callback', (
      tester,
    ) async {
      await _pump(
        tester,
        _app(
          ChatwootChat(
            options: const ChatwootChatOptions(
              baseUrl: 'b',
              inboxIdentifier: 'i',
              enableAttachments: false,
              enableVoiceMessages: false,
            ),
            clientFactory: factory.call,
          ),
        ),
      );

      expect(find.byTooltip('Attach a file or image'), findsNothing);
      expect(find.byTooltip('More options'), findsNothing);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    });

    testWidgets('an app bar replaces the style header', (tester) async {
      await _pump(
        tester,
        _app(
          ChatwootChat(
            options: _o,
            title: 'Header title',
            appBar: AppBar(title: const Text('App bar')),
            clientFactory: factory.call,
          ),
        ),
      );

      expect(find.text('App bar'), findsOneWidget);
      expect(find.text('Header title'), findsNothing);
    });

    testWidgets('strings follow the app locale when l10n is null', (
      tester,
    ) async {
      await _pump(
        tester,
        MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: const [Locale('uz'), Locale('en')],
          localizationsDelegates: const [
            _FallbackMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            _FallbackCupertinoDelegate(),
          ],
          home: ChatwootChat(options: _o, clientFactory: factory.call),
        ),
      );

      expect(find.text(ChatwootL10n.uzLatn.inputPlaceholder), findsOneWidget);
      expect(find.text(ChatwootL10n.uzLatn.headerTitle), findsOneWidget);
    });
  });

  group('l10n translations', () {
    test('forLocale picks the built-in translation', () {
      expect(ChatwootL10n.forLocale(const Locale('ru')), ChatwootL10n.ru);
      expect(ChatwootL10n.forLocale(const Locale('tr')), ChatwootL10n.tr);
      expect(ChatwootL10n.forLocale(const Locale('kaa')), ChatwootL10n.kaa);
      expect(ChatwootL10n.forLocale(const Locale('uz')), ChatwootL10n.uzLatn);
      expect(
        ChatwootL10n.forLocale(
          const Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
        ),
        ChatwootL10n.uzCyrl,
      );
      expect(ChatwootL10n.forLocale(const Locale('de')), const ChatwootL10n());
      expect(ChatwootL10n.forLocale(null), const ChatwootL10n());
    });

    test('translations differ from English and from each other', () {
      const all = [
        ChatwootL10n(),
        ChatwootL10n.ru,
        ChatwootL10n.uzLatn,
        ChatwootL10n.uzCyrl,
        ChatwootL10n.tr,
        ChatwootL10n.kaa,
      ];
      expect(all.map((l) => l.inputPlaceholder).toSet(), hasLength(all.length));
      expect(all.toSet(), hasLength(all.length));
    });
  });
}

/// English material strings for any locale (the test app has no
/// flutter_localizations).
class _FallbackMaterialLocalizations extends DefaultMaterialLocalizations {
  const _FallbackMaterialLocalizations();

  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _FallbackDelegate();
}

class _FallbackDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
        const _FallbackMaterialLocalizations(),
      );

  @override
  bool shouldReload(_FallbackDelegate old) => false;
}

class _FallbackCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(_FallbackCupertinoDelegate old) => false;
}
