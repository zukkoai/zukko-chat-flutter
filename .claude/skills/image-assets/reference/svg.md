# SVG (flutter_svg)

Flutter doesn't render SVG natively. Use `flutter_svg`; for hot paths precompile with `vector_graphics_compiler`.

```bash
flutter pub add flutter_svg              # latest; baseline ^2.0
# changelog: pub.dev/packages/flutter_svg/changelog
```

## Rendering

```dart
import 'package:flutter_svg/flutter_svg.dart';

SvgPicture.asset('assets/icons/logo.svg', width: 48, height: 48);
SvgPicture.network('https://example.com/icon.svg');
SvgPicture.string(svgMarkup);
```

## Tinting — colorFilter (NOT color)

The `color:` parameter was **removed** from `flutter_svg`. Use `colorFilter:`:
```dart
// REMOVED — known AI mistake (compile error on current versions)
SvgPicture.asset('icon.svg', color: Colors.red);

// CURRENT
SvgPicture.asset(
  'icon.svg',
  colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
);
```
- `BlendMode.srcIn` recolors the whole shape with the given color (the usual "tint an icon" mode).
- Omit `colorFilter` to keep the SVG's own colors.

## Sizing & fit

```dart
SvgPicture.asset('art.svg',
  width: 200, fit: BoxFit.contain,
  placeholderBuilder: (context) => const SizedBox(
    width: 200, height: 200, child: Center(child: CircularProgressIndicator())));
```
SVGs are vector — they scale crisply at any size with no decode-memory penalty (unlike raster images). No `cacheWidth` needed.

## Precompiling with vector_graphics

For many SVGs or perf-sensitive screens, precompile `.svg` → `.vec` (binary `vector_graphics` format) so there's no runtime XML parsing.

```bash
dart pub global activate vector_graphics_compiler
vector_graphics_compiler -i assets/icons/logo.svg -o assets/icons/logo.svg.vec
```
```dart
import 'package:vector_graphics/vector_graphics.dart';

VectorGraphic(loader: const AssetBytesLoader('assets/icons/logo.svg.vec'));
```
- Faster first paint; smaller, parse-free runtime cost.
- Declare the `.vec` files as assets in `pubspec.yaml`.
- Worth it for icon-heavy UIs and any SVG painted frequently.

## Gotchas
- **`color:` is removed** — use `colorFilter: ColorFilter.mode(c, BlendMode.srcIn)`. This is the top flutter_svg AI mistake.
- `SvgPicture.network` has **no disk cache** — cache bytes yourself or ship/precompile the asset.
- Unsupported SVG features (some filters, advanced gradients) may render differently — test the actual file.
- Declare `.svg`/`.vec` assets in `pubspec.yaml` or you get an asset-load error.
