# Semantics widget

Flutter builds a **semantics tree** parallel to the widget tree; screen readers (TalkBack, VoiceOver) read it, not the rendered pixels. Anything not in the tree is invisible to assistive tech.

## Contents
1. [Labels, value, hint, role](#labels-value-hint-role)
2. [Icon-only buttons & gestures](#icon-only-buttons--gestures)
3. [Merge & exclude](#merge--exclude)
4. [Decorative vs meaningful images](#decorative-vs-meaningful-images)
5. [Live regions & announcements](#live-regions--announcements)
6. [Custom semantic actions](#custom-semantic-actions)
7. [Headers, links, sliders](#headers-links-sliders)

## Labels, value, hint, role

```dart
Semantics(
  label: 'Volume',        // what it is
  value: '70%',           // current state
  hint: 'Double tap to adjust', // what happens
  slider: true,           // role flag
  child: const VolumeBar(),
)
```
- **label** — name of the control (localize it).
- **value** — dynamic state (percentage, selected option).
- **hint** — the action result; keep short.
- **Role flags**: `button: true`, `header: true`, `link: true`, `image: true`, `textField: true`, `slider: true`, `checked:`, `selected:`, `enabled:`.

## Icon-only buttons & gestures

The single most common defect. An `IconButton` with only an icon and no `tooltip` is announced as *"button"* with no name.

```dart
// Do — tooltip doubles as the semantic label
IconButton(icon: const Icon(Icons.share), tooltip: 'Share', onPressed: _share);

// Custom gesture — wrap in Semantics
Semantics(
  label: 'Favorite',
  button: true,
  onTap: _favorite,
  child: GestureDetector(onTap: _favorite, child: const Icon(Icons.star_border)),
);
```
Same rule for `InkWell`, `GestureDetector`, and custom-painted controls.

## Merge & exclude

```dart
// MergeSemantics — read a label + value as ONE node
MergeSemantics(
  child: Row(children: [const Text('Status:'), Text(status)]),
);

// ExcludeSemantics — silence children you describe yourself
Semantics(
  label: 'Rating 4 of 5 stars',
  child: ExcludeSemantics(child: const StarRow(filled: 4)),
);
```
- Use **MergeSemantics** so a list tile reads as one item, not 3 fragments.
- Use **ExcludeSemantics** when the parent `Semantics(label:)` already says everything.

## Decorative vs meaningful images

```dart
Image.asset('assets/divider.png', excludeFromSemantics: true);           // decorative → silent
Image.asset('assets/chart.png', semanticLabel: 'Sales up 12% this quarter'); // meaningful → describe
Icon(Icons.warning, semanticLabel: 'Warning');                            // standalone icon meaning
```
Default-announcing every decorative image floods the screen reader with noise.

## Live regions & announcements

```dart
// One-off announcement (e.g. "Item added to cart")
import 'package:flutter/semantics.dart';
SemanticsService.announce('Item added to cart', TextDirection.ltr);

// Region that should re-announce when its content changes
Semantics(liveRegion: true, child: Text(statusMessage));
```
Use for async results, validation errors, and toast-like updates that a screen-reader user would otherwise miss.

## Custom semantic actions

Expose actions beyond tap so assistive tech can offer them in its menu:
```dart
Semantics(
  label: 'Message from Alex',
  customSemanticsActions: {
    const CustomSemanticsAction(label: 'Reply'): _reply,
    const CustomSemanticsAction(label: 'Delete'): _delete,
  },
  child: MessageTile(message: m),
);
```

## Headers, links, sliders

- **Header**: `Semantics(header: true, child: Text('Settings'))` — lets users jump by heading.
- **Link**: `Semantics(link: true, child: ...)` for in-text navigation.
- **Slider/adjustable**: set `slider: true` + `value:` and handle `onIncrease`/`onDecrease` so it's adjustable by gesture.
- **Text fields**: `TextField` is labeled via its `InputDecoration(labelText:)` — that becomes the semantic label automatically.

## Debugging the tree

Toggle the semantics overlay to see what assistive tech sees:
```dart
import 'package:flutter/rendering.dart';
void main() {
  debugSemanticsDisableAnimations; // (debug flags)
  // In app: WidgetsApp(showSemanticsDebugger: true) or DevTools > Widget Inspector > Semantics
}
```
Or `flutter run` then open DevTools → Widget Inspector → enable the semantics debugger.
