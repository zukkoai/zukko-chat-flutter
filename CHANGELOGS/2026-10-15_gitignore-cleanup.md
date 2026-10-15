# Gitignore cleanup

## What
- Root `.gitignore`: added coverage, secrets/signing (`.env*`, `*.jks`, `*.keystore`, `*.p12`, `*.p8`, `*.mobileprovision`, `google-services.json`, `GoogleService-Info.plist`, `key.properties`), `.fvm/`, `.vscode/`, OS/editor leftovers, Claude local files (`.claude/settings.local.json`, `.claude/worktrees/`), and root `/pubspec.lock`. `TODO.md` stays ignored.
- `example/.gitignore`: added the same secrets/signing, coverage, `.fvm/`, `.vscode/` rules.
- `.claude/skills/**` and `example/pubspec.lock` stay tracked.

## Why
Dart convention: a package does not commit its lockfile; an app (example/) may. Nothing else junk was tracked.

## Un-tracked (`git rm --cached`, files kept on disk)
- `pubspec.lock` (root)
