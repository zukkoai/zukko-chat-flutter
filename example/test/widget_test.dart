import 'package:example/home_screen.dart';
import 'package:example/live/live_chat_screen.dart';
import 'package:example/live/live_config.dart';
import 'package:example/live/not_configured_view.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home shows the 3 styles, the dark switch and the buttons', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Silk'), findsOneWidget);
    expect(find.text('Minimal'), findsOneWidget);
    expect(find.text('Thread'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Open chat'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('dark switch changes the app theme', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    BuildContext ctx() => tester.element(find.byType(HomeScreen));
    expect(Theme.of(ctx()).brightness, Brightness.light);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(Theme.of(ctx()).brightness, Brightness.dark);
  });

  testWidgets('without dart-defines the chat shows the run instructions', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Open chat'));
    await tester.pumpAndSettle();

    expect(find.byType(NotConfiguredView), findsOneWidget);
    expect(find.textContaining('not configured'), findsOneWidget);
    expect(find.textContaining('--dart-define=ZUKKO_BASE_URL'), findsOneWidget);
    expect(
      find.textContaining('--dart-define=ZUKKO_WEBSITE_TOKEN'),
      findsOneWidget,
    );
  });

  testWidgets('LiveChatScreen with empty config is the not-configured view', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveChatScreen(config: LiveConfig())),
    );
    expect(find.byType(NotConfiguredView), findsOneWidget);
  });

  group('LiveConfig', () {
    test('configured only with url and token', () {
      expect(const LiveConfig().isConfigured, isFalse);
      expect(const LiveConfig(baseUrl: 'https://x.test').isConfigured, isFalse);
      expect(
        const LiveConfig(
          baseUrl: 'https://x.test',
          websiteToken: 't',
        ).isConfigured,
        isTrue,
      );
    });

    test('no user id means anonymous visitor', () {
      expect(const LiveConfig(userHash: 'h').user, isNull);
    });

    test('user id without hash', () {
      final u = const LiveConfig(userId: 'u1').user!;
      expect(u.identifier, 'u1');
      expect(u.identifierHash, isNull);
    });

    test('user id with hash', () {
      final u = const LiveConfig(userId: 'u1', userHash: 'abc').user!;
      expect(u.identifier, 'u1');
      expect(u.identifierHash, 'abc');
    });
  });
}
