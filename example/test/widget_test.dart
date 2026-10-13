import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home lists the three ways to open the chat', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Native chat (page)'), findsOneWidget);
    expect(find.text('Native chat (dialog)'), findsOneWidget);
    expect(find.text('Web widget'), findsOneWidget);
  });
}
