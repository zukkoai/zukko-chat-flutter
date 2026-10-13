# Integration tests and E2E

Use the `integration_test` package — `flutter_driver` is deprecated. Tests live in `integration_test/`.

```dart
// integration_test/app_test.dart
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full sign-in flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'a@b.com');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
```

Run with `flutter test integration_test`.

## When to reach for patrol

For advanced E2E (native dialogs, OS permission prompts, deep links, notifications), use **`patrol`** (4.6.1), which extends `integration_test` with native automation. It can tap native UI outside the Flutter view (e.g. an Android permission dialog) that `integration_test` alone cannot reach.

```dart
patrolTest('grants location and continues', ($) async {
  await $.pumpWidgetAndSettle(const MyApp());
  await $(#enableLocation).tap();
  await $.native.grantPermissionWhenInUse();   // native dialog
  await $(#continue).tap();
  expect($('Nearby places'), findsOneWidget);
});
```
