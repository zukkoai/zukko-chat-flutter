# Network images (cached_network_image)

`Image.network` has **no disk cache** and re-fetches whenever the widget rebuilds. For real network images use `cached_network_image`.

```bash
flutter pub add cached_network_image   # latest; baseline ^3.4
# changelog: pub.dev/packages/cached_network_image/changelog
```

## Basic usage

```dart
import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: url,
  fit: BoxFit.cover,
  placeholder: (context, url) =>
      const Center(child: CircularProgressIndicator()),
  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
);
```
- Caches to **disk + memory** automatically; survives rebuilds and app restarts.
- `placeholder` / `progressIndicatorBuilder` show while loading; `errorWidget` handles failures.

## Capping decode & disk size (memory safety)

```dart
CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: 600,        // decode width in logical px — caps RGBA memory
  memCacheHeight: 800,       // optional; one dimension is usually enough
  maxWidthDiskCache: 1200,   // resize before storing on disk
  fit: BoxFit.cover,
);
```
- **`memCacheWidth`/`memCacheHeight`** are the CNI equivalent of `cacheWidth`/`cacheHeight` — they control **decode** memory. Without them the full image is decoded to RGBA.
- **`maxWidthDiskCache`/`maxHeightDiskCache`** shrink the bytes stored on disk.
- In a list, always set `memCacheWidth` to roughly the on-screen pixel width (logical width × devicePixelRatio).

## As an ImageProvider

Use `CachedNetworkImageProvider` where an `ImageProvider` is expected (e.g. `DecorationImage`, `CircleAvatar`):
```dart
CircleAvatar(backgroundImage: CachedNetworkImageProvider(url));
Container(decoration: BoxDecoration(
  image: DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover)));
```

## Pre-warming the cache

```dart
await precacheImage(CachedNetworkImageProvider(heroUrl), context); // before navigating
```

## Customizing / clearing the cache

```dart
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Clear all cached network images
await DefaultCacheManager().emptyCache();

// Custom retention (e.g. shorter TTL, smaller cap)
final manager = CacheManager(Config(
  'myImages',
  stalePeriod: const Duration(days: 7),
  maxNrOfCacheObjects: 200,
));
CachedNetworkImage(imageUrl: url, cacheManager: manager);
```

## When `Image.network` is fine
- Small, one-off images that won't rebuild repeatedly (e.g. a single static logo behind a feature flag).
- Anything in a list, a feed, avatars, or images that rebuild → use `cached_network_image`.

## Gotchas
- No `memCacheWidth` on feed images → full-res RGBA per item → OOM (see `memory-and-decode.md`).
- `Image.network` inside a `ListView.builder` → re-downloads on scroll recycle; switch to CNI.
- Forgetting `errorWidget` → a broken layout on a 404/timeout instead of a graceful fallback.
