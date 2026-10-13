# Golden (visual regression) tests

Use **`alchemist`** (0.14.0, the current standard) — `golden_toolkit` is discontinued. Pin device pixel ratio and bundle fonts, or goldens flake across machines.

```dart
goldenTest(
  'PrimaryButton renders correctly',
  fileName: 'primary_button',
  builder: () => GoldenTestGroup(
    children: [
      GoldenTestScenario(name: 'enabled', child: const PrimaryButton(label: 'Save')),
      GoldenTestScenario(name: 'disabled', child: const PrimaryButton(label: 'Save', onTap: null)),
    ],
  ),
);
```

Plain `flutter_test` goldens use `matchesGoldenFile`:

```dart
await expectLater(find.byType(PrimaryButton), matchesGoldenFile('goldens/button.png'));
```

## Generating and keeping goldens stable

- Generate/update with `flutter test --update-goldens`.
- Load real fonts in `flutter_test_config.dart` so text isn't rendered as boxes (the default test font has no glyphs).
- **Pin DPR** so a HiDPI machine doesn't double the pixels and diff against a 1x baseline.
- Run goldens that contain native **iOS** fonts on **macOS** in CI; everything else on Linux — font rasterization differs per platform.

```dart
// flutter_test_config.dart — load fonts once for all tests
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();   // from alchemist / a font-loading helper
  return testMain();
}
```
