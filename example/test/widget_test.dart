import 'package:example/live/live_config.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('home shows the three styles and the live chat entry', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.byType(FilledButton), findsNWidgets(3));
    expect(find.text('Live chat'), findsOneWidget);
  });

  for (final style in ['Smooth Silk', 'Minimal Clean', 'Thread Feed']) {
    testWidgets('$style opens the demo chat', (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.tap(find.text(style));
      await _settle(tester);

      expect(find.text('Zukko AI'), findsWidgets);
      expect(find.textContaining('kuryer ertaga'), findsWidgets);
    });
  }

  testWidgets('live chat shows a placeholder when not configured', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Live chat'));
    await _settle(tester);

    expect(find.textContaining('not configured'), findsOneWidget);
  });

  test('LiveConfig: configured only with url and token', () {
    expect(const LiveConfig().isConfigured, isFalse);
    expect(const LiveConfig(baseUrl: 'https://x.test').isConfigured, isFalse);
    expect(
      const LiveConfig(
        baseUrl: 'https://x.test',
        websiteToken: 't',
      ).isConfigured,
      isTrue,
    );
    expect(const LiveConfig().user, isNull);
    expect(const LiveConfig(userId: 'u1').user?.identifier, 'u1');
  });
}
