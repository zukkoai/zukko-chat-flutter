# Adaptive navigation

Bottom nav on narrow screens; rail/drawer on wide ones.

```dart
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.index, required this.onTap, required this.body});
  final int index;
  final ValueChanged<int> onTap;
  final Widget body;

  static const _dests = [
    (icon: Icons.home, label: 'Home'),
    (icon: Icons.search, label: 'Search'),
    (icon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: onTap,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _dests)
                NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        destinations: [
          for (final d in _dests)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
```

## Platform-adaptive widgets

Use `.adaptive` constructors to match the host platform automatically: `Switch.adaptive`, `Slider.adaptive`, `CircularProgressIndicator.adaptive`, `showAdaptiveDialog`. They render Cupertino on iOS/macOS and Material elsewhere.

## Do / avoid

- Do scale with constraints, `Expanded`, and fractions, not fixed pixels.
- Do honor `textScaler`, `SafeArea`, and `viewInsets` (keyboard).
- Do switch navigation pattern by width class.
- Avoid `MediaQuery.of(context)` when a `*Of` selector suffices (fewer rebuilds).
- Avoid deprecated `textScaleFactor` — use `textScaler`.
