# Contrast, touch targets & focus

WCAG 2.2 AA (and EN 301 549, referenced by the EU EAA) sets the numeric bars Flutter apps are tested against.

## Color contrast

| Content | Minimum ratio (AA) |
|---|---|
| Body text (< 18pt / < 14pt bold) | **4.5:1** |
| Large text (≥ 18pt / ≥ 14pt bold) | **3:1** |
| UI components, icons, focus indicators | **3:1** |

- Contrast is foreground vs its actual background — check disabled, hover, and dark-mode states too.
- **Never rely on color alone** to convey meaning (error/success/required). Pair with an icon, text, or shape — required for colorblind users and WCAG 1.4.1.
- Verify in tests with `textContrastGuideline` (below) and design-time with any contrast checker.

```dart
// Color alone (fails 1.4.1) — only red border signals error
TextField(decoration: InputDecoration(border: redBorder));
// Do — color + icon + text
TextField(decoration: InputDecoration(
  border: redBorder,
  errorText: 'Email is required',
  prefixIcon: const Icon(Icons.error_outline),
));
```

## Touch targets (≥ 48×48 dp)

Material requires a minimum **48×48 dp** hit area; iOS HIG ~44pt. Visual size can be smaller, but the tappable region must meet the floor.

```dart
// Small icon → pad the hit area to 48dp
IconButton(
  icon: const Icon(Icons.close, size: 20),
  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  padding: EdgeInsets.zero,
  tooltip: 'Close',
  onPressed: _close,
);

// Custom tap region — wrap in a sized box
SizedBox(
  width: 48, height: 48,
  child: Center(child: GestureDetector(onTap: _tap, child: const Icon(Icons.add, size: 24))),
);

// App-wide: keep the default (don't shrink below the floor)
MaterialApp(theme: ThemeData(materialTapTargetSize: MaterialTapTargetSize.padded));
```
`MaterialTapTargetSize.shrinkWrap` removes the 48dp padding — only use it when you've guaranteed the target floor another way.

## Focus order & traversal

Screen-reader swipe order and keyboard Tab order follow the focus tree. Fix illogical order explicitly:
```dart
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: Column(children: [
    FocusTraversalOrder(order: const NumericFocusOrder(1), child: nameField),
    FocusTraversalOrder(order: const NumericFocusOrder(2), child: emailField),
    FocusTraversalOrder(order: const NumericFocusOrder(3), child: submitButton),
  ]),
);
```
- Group related controls with `FocusTraversalGroup`.
- Move focus on screen change: `FocusScope.of(context).requestFocus(node)`.
- Ensure a **visible focus indicator** (Flutter draws one by default; don't strip it) with ≥ 3:1 contrast.

## Live regions

Announce content that changes without user action so it isn't missed:
```dart
SemanticsService.announce('5 results found', Directionality.of(context));
// or a region that re-announces on change:
Semantics(liveRegion: true, child: Text('$count items'));
```

## Checklist
- [ ] All text meets 4.5:1 (3:1 for large/UI).
- [ ] No state conveyed by color alone.
- [ ] Every interactive element ≥ 48×48 dp.
- [ ] Logical focus/swipe order; visible focus ring.
- [ ] Dynamic updates announced (live region or `announce`).
