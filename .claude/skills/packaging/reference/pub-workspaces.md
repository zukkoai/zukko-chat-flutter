# Pub workspaces (Dart 3.6+)

Native pub workspaces resolve every package in a monorepo together against **one shared lockfile**. No external tool is required for resolution — this is built into `dart pub` / `flutter pub`.

## Requirements
- Dart SDK **3.6.0+** (Flutter 3.27+). Every member's `environment.sdk` must allow it.

## Root pubspec
The repo root is itself a (usually non-publishable) package that lists its members:
```yaml
# /pubspec.yaml
name: my_monorepo
publish_to: none
environment:
  sdk: ^3.6.0
workspace:
  - packages/app
  - packages/core
  - packages/api_client
```
- `workspace:` entries are directory paths to member packages.
- The root may also declare shared `dev_dependencies` (e.g. lints) inherited workspace-wide.

## Member pubspec
Each member opts into the shared resolution:
```yaml
# /packages/core/pubspec.yaml
name: core
environment:
  sdk: ^3.6.0
resolution: workspace        # REQUIRED — joins the workspace
dependencies:
  meta: ^1.15.0
```
- Without `resolution: workspace`, the package is resolved independently and gets its own lockfile — defeating the point.
- Members reference each other by name with a normal dependency; the workspace resolves the local path automatically (no `path:` needed):
  ```yaml
  dependencies:
    core: ^1.0.0           # resolved to the local member, not pub.dev
  ```

## One lockfile, one get
```bash
dart pub get               # from anywhere in the workspace resolves ALL members
```
- A single `pubspec.lock` lives at the **root**. Per-member lockfiles disappear.
- **Commit the root `pubspec.lock`** for apps/workspaces (reproducible installs). Pure libraries normally gitignore lockfiles, but a workspace root that contains apps should commit it.

## Avoid overrides
- Don't use `pubspec_overrides.yaml` or `dependency_overrides:` `path:` entries to wire local packages — the workspace already resolves members locally.
- Any package you intend to **publish** must not rely on overrides; pub.dev can't honor them.

## Migrating an existing monorepo
1. Bump all members to `sdk: ^3.6.0`.
2. Add the `workspace:` list to the root pubspec.
3. Add `resolution: workspace` to each member.
4. Delete per-member `pubspec.lock` and any `pubspec_overrides.yaml` used only for local wiring.
5. `dart pub get` at the root; commit the single root lockfile.
