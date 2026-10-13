# Text scaling (TextScaler)

Users can enlarge system font size to 200%+ (iOS Dynamic Type, Android font scale). Your layout must adapt or it clips, overflows, and becomes unreadable.

## TextScaler API (current)

`textScaleFactor` (a `double`) was **deprecated in Flutter 3.16** and replaced by `TextScaler`, which supports non-linear scaling.

```dart
// Read the scaler
final TextScaler scaler = MediaQuery.textScalerOf(context);   // NOT textScaleFactorOf

// Apply / override on a specific Text
Text('Hello', textScaler: TextScaler.noScaling);              // opt a label out of scaling
Text('Hello', textScaler: scaler.clamp(maxScaleFactor: 1.5)); // cap the scale

// Compute a scaled dimension when you truly need one
final double scaledIcon = scaler.scale(24);
```

| Deprecated (AI mistake) | Current |
|---|---|
| `MediaQuery.textScaleFactorOf(context)` | `MediaQuery.textScalerOf(context)` |
| `Text(..., textScaleFactor: 1.2)` | `Text(..., textScaler: TextScaler.linear(1.2))` |
| `MediaQuery(data: data.copyWith(textScaleFactor: ...))` | `copyWith(textScaler: TextScaler.linear(...))` |

## Overflow-safe layouts

The goal: text **wraps or ellipsizes** instead of clipping, and rows **grow** instead of overflowing.

```dart
// 1. Let text take the space it needs
Row(children: [
  const Icon(Icons.label),
  const SizedBox(width: 8),
  Flexible(child: Text(title, overflow: TextOverflow.ellipsis)), // Flexible, not fixed width
]);

// 2. Wrap chips/buttons that won't fit on one line
Wrap(spacing: 8, runSpacing: 8, children: chips);

// 3. Shrink a fixed-design element only when it must stay one line
FittedBox(fit: BoxFit.scaleDown, child: Text(bigNumber));

// 4. Avoid hardcoded heights around text
// Avoid: SizedBox(height: 48, child: Center(child: Text(label)))  // clips at 200%
// Do:    Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(label))
```

## Capping scale (use sparingly)

If a screen genuinely cannot accommodate unbounded scale, clamp rather than disable:
```dart
MediaQuery.withClampedTextScaling(
  maxScaleFactor: 1.3,
  child: const DenseDashboard(),
);
```
Never set `TextScaler.noScaling` app-wide — that breaks accessibility. Clamp narrowly and only where unavoidable.

## Testing at large scale

```dart
testWidgets('survives 200% text', (tester) async {
  tester.platformDispatcher.textScaleFactorTestValue = 2.0; // or wrap in MediaQuery
  await tester.pumpWidget(const MyApp());
  expect(tester.takeException(), isNull); // no overflow/RenderFlex error
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
});
```
Manual: device settings → set largest font / display size → walk every screen and check nothing clips or overlaps.

## Gotchas
- A `RenderFlex overflowed` yellow-black banner at 200% means a hardcoded constraint — replace with `Flexible`/`Wrap`/`Expanded`.
- Buttons with `maxLines: 1` and no `overflow:` clip silently — add `overflow: TextOverflow.ellipsis` or allow wrapping.
- Icons sized in logical px don't scale with text by default; scale meaningful glyphs via `scaler.scale(...)` if they must track text.
