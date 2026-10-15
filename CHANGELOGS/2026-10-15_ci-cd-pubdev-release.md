# CI/CD: tests on every branch, pub.dev release from main

## What
`.github/` was cleaned and now holds two workflows. `test.yml` (analyze + test after build_runner) runs on every push except `main`, on pull requests, and is reusable. `release.yml` runs on `main` and on `v*` tags: on `main` it runs the tests and creates tag `v<pubspec version>` (skipped if already released); the tag run tests again and publishes to pub.dev with `flutter pub publish --force` via GitHub OIDC. `.pubignore` now also excludes `test/`; `pubspec.yaml` gained `repository` and `issue_tracker`.

## Why
pub.dev automated publishing only accepts runs triggered by a tag push, and a tag pushed with the default `GITHUB_TOKEN` triggers no workflow, so the tag job uses a PAT.

## Setup required
1. GitHub secret `RELEASE_TOKEN`: fine-grained PAT, repository `zukko-chat-flutter`, permission Contents: read & write.
2. GitHub environment `pub.dev` (Settings -> Environments); protection rules optional (e.g. required reviewer).
3. pub.dev package -> Admin -> Automated publishing -> enable GitHub Actions: repository `alisheraxmedov/zukko-chat-flutter`, tag pattern `v{{version}}`, require environment `pub.dev`. The package must exist on pub.dev first (first release is a manual `flutter pub publish`).
