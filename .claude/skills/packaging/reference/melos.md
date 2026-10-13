# Melos 7.x — monorepo tooling on pub workspaces

Melos 7 builds **on top of native pub workspaces**. It no longer manages dependency resolution or bootstrapping the way Melos 3–6 did — pub does that. Melos adds scripts, multi-package commands, and coordinated versioning/publishing.

> **There is no `melos.yaml` in Melos 7.** Config moved into a **`melos:` key in the root `pubspec.yaml`**. Generating a `melos.yaml` file is a known AI mistake — Melos 7 ignores it.

## Install
```bash
dart pub global activate melos      # 7.x
```

## Config lives in the root pubspec
```yaml
# /pubspec.yaml  (the workspace root)
name: my_monorepo
publish_to: none
environment:
  sdk: ^3.6.0
workspace:
  - packages/app
  - packages/core

melos:
  scripts:
    analyze:
      run: dart analyze .
      exec: { concurrency: 5 }       # run per-package
    test:
      run: flutter test
      exec: { concurrency: 1 }
      packageFilters:
        flutter: true                # only Flutter packages
    format-check:
      run: dart format --set-exit-if-changed .
```
- `workspace:` is the pub key (which packages exist). `melos:` is the Melos config block.
- No separate Melos "packages" globbing is needed — Melos reads the pub `workspace:` members.

## Running
```bash
melos run analyze        # runs the script across workspace packages
melos run test
melos list               # list workspace packages
melos exec -- dart pub get   # arbitrary command per package
```
`melos bootstrap` is largely a no-op now — `dart pub get` at the root already links everything via the workspace.

## Versioning & publishing
Melos automates conventional-commit versioning and tagging:
```bash
melos version           # bump versions + update CHANGELOGs from commits, create tags
melos publish --dry-run # validate publishable packages
melos publish           # publish changed packages
```
- Configure under `melos:`:
  ```yaml
  melos:
    command:
      version:
        linkToCommits: true
        branch: main
      publish:
        hooks:
          pre: dart analyze .
  ```
- `melos version` respects each package's `publish_to`; set `publish_to: none` on private packages so they're versioned but never pushed to pub.dev.

## Migrating from `melos.yaml`
1. Move `scripts:` and `command:` blocks from `melos.yaml` into a `melos:` key in the root `pubspec.yaml`.
2. Replace the old `packages:` globs with the pub `workspace:` list and `resolution: workspace` on members (see `pub-workspaces.md`).
3. Delete `melos.yaml`.
4. `dart pub get` at the root; run `melos list` to confirm members are picked up.
