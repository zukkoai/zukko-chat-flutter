# dart fix — automated API migration

`dart fix` applies the quick-fixes the analyzer already knows about — most deprecations ship a fix. It is the modern migration command.

> **`dart migrate` was removed.** It was the one-time null-safety migration tool (Dart 2.12 era). It no longer exists. Referencing it is a known AI mistake. Use `dart fix`.

## Workflow
```bash
dart fix --dry-run     # preview: lists every change grouped by fix type, no edits
dart fix --apply       # apply all available fixes in place
```
Run it from the package/project root. With fvm: `fvm dart fix --apply`.

Typical dry-run output:
```
12 proposed fixes in 4 files.

lib/theme.dart
  3 fixes:  use 'withValues' instead of 'withOpacity'  (deprecated_member_use)
lib/buttons.dart
  2 fixes:  rename 'MaterialStateProperty' to 'WidgetStateProperty'
```

## What it can and can't do
- **Can**: apply deprecation renames, add required `const`, remove dead `// ignore`, apply lint auto-fixes, migrate APIs that registered a fix.
- **Can't**: change runtime behavior or fix APIs with no registered fix — those still need manual edits guided by the breaking-changes doc.

## Scope the fixes
Apply only specific diagnostics/lints:
```bash
dart fix --apply --code=deprecated_member_use
dart fix --apply --code=prefer_const_constructors
```
Useful to migrate one deprecation at a time and keep diffs reviewable.

## Recommended sequence per upgrade
1. Bump the SDK (fvm) and `pubspec` constraints; `flutter pub get`.
2. `dart fix --dry-run` — read what it will touch.
3. `dart fix --apply`.
4. `flutter analyze` — handle anything `dart fix` couldn't auto-fix.
5. Run tests.
6. Commit the migration as its own change so it's easy to review/revert.

## Custom fixes from packages
Packages can ship their own fixes via a `fix_data.yaml`; when you depend on such a package, its deprecation renames also surface in `dart fix`. Lints from `package:flutter_lints` / `package:lints` that are auto-fixable are applied the same way — enable them in `analysis_options.yaml` so `dart fix` can act on them.
