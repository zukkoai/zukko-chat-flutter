# Responsive scaffold notes

## MediaQuery essentials (detail)

Read once per build; prefer the narrow `*Of` selectors to avoid rebuilds.

```dart
final size = MediaQuery.sizeOf(context);          // logical px
final padding = MediaQuery.paddingOf(context);     // notches, system bars
final insets = MediaQuery.viewInsetsOf(context);   // keyboard height
final scaler = MediaQuery.textScalerOf(context);   // use textScaler...
final scaled = scaler.scale(16);                   // ...not deprecated textScaleFactor
```

Respect `textScaler` — never lock font sizes; let text grow for accessibility.

## Composing breakpoints + orientation

Combine the `Responsive` builder (width class) with `OrientationBuilder` and `Wrap`/`Expanded` for a full adaptive screen:

```dart
Responsive(
  mobile: ListView(children: cards),
  tablet: GridView.count(crossAxisCount: 2, children: cards),
  desktop: Row(children: [
    const SizedBox(width: 280, child: Sidebar()),
    Expanded(child: GridView.count(crossAxisCount: 3, children: cards)),
  ]),
)
```

## flutter_screenutil

For pixel-perfect designs scaled from a reference frame, `flutter_screenutil` provides `.w`, `.h`, `.sp` extensions tied to a design size. Useful when a design spec is in fixed dimensions — but prefer constraint-based layout first, and don't apply `.sp` on top of `textScaler` (you'll double-scale text).
