# Assets, fonts & icon tree-shaking

Assets are usually the biggest, cheapest win. Compress, use the right format, ship only what you need.

## Contents
1. [Image formats — WebP](#image-formats--webp)
2. [Resolution variants](#resolution-variants)
3. [Font subsetting](#font-subsetting)
4. [Icon tree-shaking](#icon-tree-shaking)
5. [Unused locales](#unused-locales)

## Image formats — WebP

WebP gives smaller files than PNG/JPG at similar quality, with alpha support.

```bash
# Convert (cwebp from the webp tools); -q lossy quality, -lossless for crisp UI art
cwebp -q 80 input.png -o output.webp
cwebp -lossless logo.png -o logo.webp
```
- Use **lossy WebP** for photos, **lossless WebP** for UI graphics/icons with hard edges.
- Flutter's `Image.asset` decodes `.webp` natively (animated WebP too).
- Strip metadata and over-large source images before bundling.

## Resolution variants

Ship density buckets instead of one huge image; Flutter picks the right one per device DPR.
```
assets/
  image.png        # 1.0x (base)
  2.0x/image.png   # 2x density
  3.0x/image.png   # 3x density
```
```yaml
# pubspec.yaml — declare the base path only
flutter:
  assets:
    - assets/image.png
```
Provide variants so high-DPR phones get sharp images **and** low-DPR devices don't download oversized ones. Avoid shipping a single 3x asset to everyone.

## Font subsetting

Custom fonts can be hundreds of KB. Flutter **subsets** declared fonts on release builds automatically (keeps only used glyphs), but you still control which families ship.

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: fonts/Inter-Regular.ttf
        - asset: fonts/Inter-Bold.ttf
          weight: 700
```
- Bundle **only the weights/styles you use** — each is a separate file.
- Prefer variable fonts only if you use several weights; a single static weight is smaller if that's all you need.
- Don't bundle a full icon font (e.g. all of Material Icons via a custom font) — let Flutter's icon tree-shaking handle Material/Cupertino icons.

## Icon tree-shaking

In **release** builds Flutter runs `--tree-shake-icons` by default: it keeps only the icon glyphs you reference, dropping the rest of the icon font (the Material font is large).

```dart
// SAFE — const reference, tree-shakeable
Icon(Icons.home);
const myIcon = Icons.settings;

// BREAKS tree-shaking — dynamic codepoint, can't be statically analyzed
final dynamicIcon = IconData(codePoint, fontFamily: 'MaterialIcons'); // ships the WHOLE font
Icon(IconData(0xe800 + index));                                       // same problem
```
If you build icons from dynamic codepoints, the tool can't prove which glyphs are used and ships the full font. Use static `Icons.*` constants, or a small custom icon set, instead.

## Unused locales

If you bundle locale data or `flutter_localizations`, you may carry every supported locale.
- For `intl`/`flutter_localizations`, limit `supportedLocales:` to what you actually ship — and prune unused ARB/`.dart` locale data.
- Some packages (timezone, currency, ICU data) bundle large datasets; check whether a slimmer variant or on-demand fetch exists.

## Verify
- Re-run `--analyze-size`; the `assets`/`fonts` nodes shrank.
- Images still look sharp on a high-DPR device (variants present).
- All referenced icons render (tree-shaking didn't drop a dynamically chosen one).
