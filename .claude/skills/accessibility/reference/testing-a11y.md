# Testing accessibility

Flutter ships automated **accessibility guideline matchers** in `flutter_test`. They catch the mechanical failures; manual screen-reader passes catch the rest.

## Guideline tests

```dart
import 'package:flutter_test/flutter_test.dart';

testWidgets('meets a11y guidelines', (tester) async {
  final handle = tester.ensureSemantics();           // build the semantics tree
  await tester.pumpWidget(const MyApp());

  await expectLater(tester, meetsGuideline(androidTapTargetGuideline)); // 48x48
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));     // 44x44
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline)); // every tappable has a label
  await expectLater(tester, meetsGuideline(textContrastGuideline));     // WCAG AA contrast

  handle.dispose();
});
```

| Guideline | Checks |
|---|---|
| `androidTapTargetGuideline` | Tappable nodes ≥ 48×48 dp |
| `iOSTapTargetGuideline` | Tappable nodes ≥ 44×44 dp |
| `labeledTapTargetGuideline` | Every tappable node has a non-empty label |
| `textContrastGuideline` | Text contrast meets WCAG AA |

- `ensureSemantics()` / the `SemanticsHandle` is required — without it the tree isn't built and matchers see nothing. Always `dispose()` it.
- `labeledTapTargetGuideline` is what fails for unlabeled `IconButton`s — wire it into CI to prevent regressions.

## Finding a specific node by semantics

```dart
expect(find.bySemanticsLabel('Delete'), findsOneWidget);
expect(find.bySemanticsLabel(RegExp(r'^\d+ items$')), findsOneWidget);
```

## Asserting a semantics shape

```dart
final node = tester.getSemantics(find.byType(MyButton));
expect(node, matchesSemantics(label: 'Submit', isButton: true, hasTapAction: true));
```

## Manual screen-reader checklist

Automated tests can't judge whether announcements make sense. Walk each screen with the reader on:

**Android — TalkBack**: Settings → Accessibility → TalkBack. Swipe right to move, double-tap to activate.
**iOS — VoiceOver**: Settings → Accessibility → VoiceOver. Swipe right to move, double-tap to activate.

- [ ] Every control announces a meaningful **name** (not "button" alone).
- [ ] State is announced (selected, checked, expanded, disabled).
- [ ] Reading order is logical top-to-bottom, left-to-right.
- [ ] Decorative images are **skipped**, not read.
- [ ] Dynamic updates (validation, results, toasts) are **announced**.
- [ ] App is fully usable at 200% text and in dark mode.
- [ ] Focus moves sensibly on navigation and dialog open/close.

## Legal context

Conformance targets you may be held to:
- **WCAG 2.2 Level AA** — the technical standard.
- **ADA** (US), **Section 508** (US federal).
- **EU EAA** (European Accessibility Act) referencing **EN 301 549**, enforced from June 2025.

Treat the guideline tests as the automated floor and the manual checklist as the real bar.
