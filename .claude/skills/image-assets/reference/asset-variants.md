# Asset declaration, variants & precaching

Bundled assets are declared in `pubspec.yaml`. Resolution variants let Flutter pick the right density per device.

## Declaring assets

```yaml
flutter:
  assets:
    - assets/images/logo.png        # single file
    - assets/icons/                 # whole directory (non-recursive)
    - assets/images/                # add a trailing slash for the folder
```
- A directory entry includes its direct files, **not** subdirectories — list each subfolder.
- Reference at runtime by the declared path: `Image.asset('assets/images/logo.png')`.

## Resolution variants (2.0x / 3.0x)

Place density buckets in sibling folders; declare only the **base** path:
```
assets/images/
  logo.png          # 1.0x (mdpi-ish baseline)
  2.0x/logo.png     # 2x density (xhdpi)
  3.0x/logo.png     # 3x density (xxhdpi)
```
```yaml
flutter:
  assets:
    - assets/images/logo.png   # base only — Flutter finds the variants
```
Flutter chooses the variant matching the device's `devicePixelRatio`, so high-DPR screens get crisp art and low-DPR devices don't load oversized files. (Cross-ref `app-size` — variants also trim download size.)

## Precaching above-the-fold images

Decode before first paint so the hero/first-screen image doesn't pop in:
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  precacheImage(const AssetImage('assets/images/hero.png'), context);
  precacheImage(CachedNetworkImageProvider(heroUrl), context);
}
```
- Call in `didChangeDependencies` (has a valid `context`), not `initState`.
- **`precacheImage` decodes at full size** — for big images pass a resized provider:
```dart
precacheImage(ResizeImage(const AssetImage('assets/images/hero.png'), width: 800), context);
```

## Asset bundle access (non-image)

```dart
final json = await rootBundle.loadString('assets/data/config.json');
final bytes = await rootBundle.load('assets/fonts/icon.ttf');
```

## Gotchas
- Path typos/missing `pubspec.yaml` entry → runtime `Unable to load asset`. Declare every path; re-run `flutter pub get` and a full restart (not hot reload) after editing `pubspec.yaml`.
- Subdirectories aren't recursive — list each folder explicitly.
- Variants must keep the **same filename** in the `2.0x`/`3.0x` folders.
- Precaching everything up front spikes memory — precache only above-the-fold images, resized.
