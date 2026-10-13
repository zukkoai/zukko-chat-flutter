# Publishing to pub.dev — pana checklist

## Contents
- [pana score components](#pana-score-components)
- [pubspec metadata](#pubspec-metadata)
- [Required files](#required-files)
- [Documentation](#documentation)
- [Pre-publish workflow](#pre-publish-workflow)
- [Verified publisher](#verified-publisher)

`pana` is the analyzer pub.dev runs to score a package. Maximize each component before publishing.

## pana score components
- **Follow Dart conventions** — passes `dart analyze` with no errors, valid `pubspec`, formatted code, recognized `LICENSE`.
- **Provide documentation** — `example/` present and dartdoc on at least 20% of public API (aim higher).
- **Platform support** — declares the platforms it works on; multi-platform scores best.
- **Pass static analysis** — no analyzer warnings/lints.
- **Support up-to-date dependencies** — depend on current versions; no discontinued packages.

## pubspec metadata
```yaml
name: my_package
description: >-
  A concise, specific one-paragraph description, 60–180 characters,
  saying what the package does. No filler.
version: 1.0.0
repository: https://github.com/me/my_package      # https, not http
homepage: https://github.com/me/my_package        # optional; https
issue_tracker: https://github.com/me/my_package/issues
topics: [networking, http]                          # discoverability
environment:
  sdk: ^3.6.0
```
- **`description`** drives search + a pana check (too short/long loses points).
- **`repository:` / `homepage:`** must be reachable **https** URLs — `http://` or 404s cost points.
- **No `author:`** — the field is **deprecated**. pub.dev attributes ownership via the **verified publisher** of the publishing account, not a pubspec field. Emitting `author:` is a known AI mistake; remove it.

## Required files
- **`LICENSE`** — a recognized SPDX license (e.g. MIT, BSD-3-Clause) in the package root. Unrecognized text loses the license check.
- **`CHANGELOG.md`** — entry for the version being published, top of file, matching `version:`.
- **`example/`** — a runnable example (an `example/lib/main.dart` or `example/example.dart`). pub.dev surfaces it on the Example tab.
- **`README.md`** — rendered as the package landing page.

## Documentation
- Add `///` dartdoc to every **public** class, method, and top-level member. Even one-line docs raise the documentation score.
- A library-level doc comment + a `library;` directive helps dartdoc group the API.
- Keep examples in dartdoc compilable (they're checked).

## Pre-publish workflow
```bash
dart pub publish --dry-run     # validate: files, pubspec, size, warnings
dart pub global activate pana  # optional: score locally
pana .                         # see the exact pub.dev report before shipping
dart pub publish               # real publish (prompts for confirmation)
```
- Fix every warning the dry-run prints (missing license, oversized package, http links) before the real publish.
- Publishing is **irreversible** for a given version number — you can't overwrite `1.0.0`, only publish `1.0.1`.

## Verified publisher
- Create/verify a publisher (a domain you own) on pub.dev, then publish the package under it. This is the modern replacement for the old `author:` field and is required for the "verified publisher" badge.
- A package can be transferred to a publisher after first publish via the pub.dev admin UI.
