import 'package:example/live/live_config.dart';
import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('home shows the live chat entry', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Live chat'), findsOneWidget);
  });

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
