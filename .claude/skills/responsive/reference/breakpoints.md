# Breakpoints & flexible layout

## LayoutBuilder for constraint-driven layout

`LayoutBuilder` gives the constraints of the **parent**, not the whole screen — ideal for widgets that adapt within a panel.

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 600) {
      return const _StackedView();
    }
    return const _SideBySideView();
  },
)
```

## Breakpoint system

Define constants and a small responsive builder; don't sprinkle magic numbers.

```dart
abstract final class Breakpoints {
  static const double tablet = 600;
  static const double desktop = 1024;
}

enum DeviceType { mobile, tablet, desktop }

DeviceType deviceTypeFor(double width) => width >= Breakpoints.desktop
    ? DeviceType.desktop
    : width >= Breakpoints.tablet
        ? DeviceType.tablet
        : DeviceType.mobile;

class Responsive extends StatelessWidget {
  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        switch (deviceTypeFor(c.maxWidth)) {
          case DeviceType.desktop:
            return desktop ?? tablet ?? mobile;
          case DeviceType.tablet:
            return tablet ?? mobile;
          case DeviceType.mobile:
            return mobile;
        }
      },
    );
  }
}
```

## Flexible building blocks (avoid hardcoded sizes)

- `Expanded` / `Flexible` — share row/column space by `flex`.
- `Wrap` — flow children to the next line when they overflow.
- `FractionallySizedBox` — size as a fraction of the parent.
- `SafeArea` — inset around notches and system bars.
- `OrientationBuilder` — branch on portrait vs landscape.

```dart
OrientationBuilder(
  builder: (_, orientation) => GridView.count(
    crossAxisCount: orientation == Orientation.portrait ? 2 : 4,
    children: items,
  ),
)
```
