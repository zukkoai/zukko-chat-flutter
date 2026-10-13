# dart:ffi + ffigen — calling C/C++

## Contents
- [When to use FFI](#when-to-use-ffi)
- [Add ffigen](#add-ffigen)
- [ffigen.yaml (current schema)](#ffigenyaml-current-schema)
- [Generate bindings](#generate-bindings)
- [Loading the library](#loading-the-library)
- [Typedefs: native vs Dart signatures](#typedefs-native-vs-dart-signatures)
- [Memory management](#memory-management)
- [Strings](#strings)
- [Native build wiring](#native-build-wiring)

## When to use FFI
Call an existing C/C++ library directly from Dart with **no platform-channel hop** — lower latency, synchronous calls. Good for crypto, codecs, math, and reusing C SDKs. Not for Java/Kotlin/Swift APIs (use channels/Pigeon for those).

## Add ffigen
```bash
flutter pub add --dev ffigen
flutter pub add ffi   # malloc/calloc/free + Utf8 helpers
```
ffigen is version-sensitive — its YAML schema has changed over releases. Generate with the **current** ffigen and verify against `pub.dev/packages/ffigen/changelog`. Do **not** copy an old `ffigen.yaml` wholesale; deprecated/renamed keys will fail or silently no-op.

## ffigen.yaml (current schema)
Minimal modern config:
```yaml
name: NativeLib
description: Bindings to native_lib
output: 'lib/src/native_lib_bindings.dart'
headers:
  entry-points:
    - 'src/native_lib.h'
preamble: |
  // ignore_for_file: type=lint
comments:
  style: any
  length: full
```
Known AI mistake: using a stale top-level `header:` or old `functions/structs` filter layout from years-old tutorials. Match the version you installed.

## Generate bindings
```bash
dart run ffigen --config ffigen.yaml
```
Produces a Dart class wrapping each C function with typed signatures.

## Loading the library
```dart
import 'dart:ffi';
import 'dart:io';
import 'src/native_lib_bindings.dart';

final DynamicLibrary _lib = () {
  if (Platform.isAndroid) return DynamicLibrary.open('libnative_lib.so');
  if (Platform.isIOS || Platform.isMacOS) return DynamicLibrary.process(); // statically linked
  if (Platform.isWindows) return DynamicLibrary.open('native_lib.dll');
  return DynamicLibrary.open('libnative_lib.so');
}();

final bindings = NativeLib(_lib);
```

## Typedefs: native vs Dart signatures
Each C function needs **two** typedefs — the native ABI type and the Dart type — when looking up manually:
```dart
// C: int32_t add(int32_t a, int32_t b);
typedef _AddNative = Int32 Function(Int32 a, Int32 b); // native types
typedef _AddDart = int Function(int a, int b);          // Dart types
final add = _lib.lookupFunction<_AddNative, _AddDart>('add');
```
Get the widths right: C `int32_t` → `Int32`, `int64_t` → `Int64`, `double` → `Double`, pointers → `Pointer<...>`. A wrong width reads/writes garbage with no compile error. ffigen generates these for you — prefer it over hand-lookup.

## Memory management
Native memory is **not** GC'd. Every allocation needs a matching free.
```dart
import 'package:ffi/ffi.dart';

// Manual:
final ptr = calloc<Int32>(4);     // allocate
try {
  ptr[0] = 7;
  nativeFn(ptr);
} finally {
  calloc.free(ptr);               // ❗ always free
}

// Preferred — Arena frees everything on scope exit:
using((Arena arena) {
  final ptr = arena<Int32>(4);    // freed automatically
  nativeFn(ptr);
});
```
Leaks here are real native leaks the Dart heap analyzer won't catch.

## Strings
C strings are `Pointer<Utf8>`. Convert both ways and free what you allocate:
```dart
final cStr = 'hello'.toNativeUtf8(); // allocates
try {
  nativeTakesString(cStr);
} finally {
  malloc.free(cStr);
}
final dartStr = nativeReturnsString().toDartString(); // copies out
```

## Native build wiring
- **Android:** build the `.so` via CMake/NDK (`android/CMakeLists.txt` referenced from `build.gradle` `externalNativeBuild`), or ship a prebuilt `jniLibs/<abi>/lib*.so`.
- **iOS/macOS:** add sources/static lib to the Xcode target or via the plugin's podspec; `DynamicLibrary.process()` resolves statically-linked symbols.
- For plugins, declare the FFI plugin in `pubspec.yaml` (`plugin: platforms: ... ffiPlugin: true`) so the toolchain builds the native code.
