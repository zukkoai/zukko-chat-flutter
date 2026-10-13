# Image memory & decoding

The #1 image bug in Flutter is decoded-memory OOM. File size on disk is irrelevant once an image is decoded.

## The RGBA math

Flutter decodes every image to **uncompressed RGBA** (4 bytes/pixel) before painting:

```
decoded bytes ≈ width(px) × height(px) × 4
```

| Image | Decoded RAM |
|---|---|
| 4000 × 3000 (12 MP photo) | ≈ **48 MB** |
| 2000 × 1500 | ≈ 12 MB |
| 600 × 800 (display size) | ≈ 1.9 MB |

A 2 MB JPEG and a 200 KB JPEG of the same dimensions cost the **same** in memory — decoding ignores file compression. A `ListView` of full-res photos exhausts memory on low-end devices fast.

## Decode at display size — cacheWidth / cacheHeight

```dart
Image.asset('photo.jpg', cacheWidth: 600);                  // decode at 600px wide
Image.network(url, cacheWidth: 600, cacheHeight: 800);      // either or both
// Via ImageProvider:
Image(image: ResizeImage(AssetImage('photo.jpg'), width: 600));
```
- Pass the **target pixel** width/height (≈ logical size × `MediaQuery.devicePixelRatioOf(context)`).
- One dimension is enough; the other scales proportionally.
- For `cached_network_image`, the equivalent is `memCacheWidth`/`memCacheHeight`.

## BoxFit / widget size do NOT reduce memory

The most common misconception:
```dart
// MYTH — this still decodes the FULL image to RGBA
SizedBox(width: 100, height: 100, child: Image.network(url, fit: BoxFit.cover));

// REALITY — cap the decode explicitly
SizedBox(width: 100, height: 100,
  child: Image.network(url, cacheWidth: 100, fit: BoxFit.cover));
```
`BoxFit`, `SizedBox`, `width`/`height`, and `ClipRRect` affect **layout/painting only**. Decode memory is fixed at decode time and only `cacheWidth`/`cacheHeight`/`memCacheWidth` change it.

## Lists — the danger zone

```dart
ListView.builder(
  itemCount: photos.length,
  itemBuilder: (context, i) => CachedNetworkImage(
    imageUrl: photos[i],
    memCacheWidth: 600,            // REQUIRED in lists — cap decode
    fit: BoxFit.cover,
  ),
);
```
- Always set a decode cap on list/grid images.
- Give items a `RepaintBoundary` if they animate (cross-ref `flutter-optimization`).

## Tuning the image cache

`PaintingBinding.instance.imageCache` holds **decoded** images. Defaults: ~1000 images / ~100 MB. For image-heavy apps:
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSizeBytes = 200 << 20;   // 200 MB cap
  cache.maximumSize = 200;              // max number of decoded images
  runApp(const MyApp());
}
// Evict a specific image when done:
imageCache.evict(NetworkImage(url));
// Clear all:
PaintingBinding.instance.imageCache.clear();
```
A single oversized decode can evict everything else (it counts against the byte budget) — another reason to cap `cacheWidth`.

## Diagnosing
- DevTools **Memory** view → look for large RGBA allocations / growth while scrolling.
- "Out of memory" / black flickering images on scroll → decode caps missing.
- Cross-ref `flutter-optimization` for `RepaintBoundary`, `ListView.builder`, and frame budget.

## Checklist
- [ ] List/grid images set `cacheWidth`/`memCacheWidth`.
- [ ] Hero/full-screen images decode at screen size, not source size.
- [ ] `imageCache` cap tuned if the app shows many images.
- [ ] No reliance on `BoxFit`/`SizedBox` to limit memory.
