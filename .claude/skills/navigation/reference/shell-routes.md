# Shell routes

## StatefulShellRoute for bottom-nav tabs

`StatefulShellRoute` gives each tab its own independent back stack. Use `StatefulNavigationShell` to switch branches.

```dart
@TypedStatefulShellRoute<MainShellRoute>(
  branches: [
    TypedStatefulShellBranch(routes: [TypedGoRoute<HomeRoute>(path: '/home')]),
    TypedStatefulShellBranch(routes: [TypedGoRoute<FeedRoute>(path: '/feed')]),
    TypedStatefulShellBranch(routes: [TypedGoRoute<ProfileRoute>(path: '/profile')]),
  ],
)
class MainShellRoute extends StatefulShellRouteData {
  const MainShellRoute();
  @override
  Widget builder(BuildContext context, GoRouterState state,
      StatefulNavigationShell shell) => ScaffoldWithNavBar(shell: shell);
}

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.shell, super.key});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.rss_feed), label: 'Feed'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );
}
```

`initialLocation: i == shell.currentIndex` makes a re-tap on the active tab pop to its root.

## ShellRoute (shared stack)

Use `ShellRoute` (not stateful) when tabs may share a single back stack — e.g. a persistent wrapper around a small set of pages that don't each need independent history.

## Nesting

Limit nesting to 2 levels — deeper trees are hard to reason about and debug.
