# CLAUDE.md

Flutter package `zukko_chat_flutter` (Zukko Chat SDK, iOS + Android). Talks to the Zukko Chat server's Widget API.
Server repo: `/Users/alisherakhmedov/Desktop/Work/microservices/chat`. Server contract + decisions: `doc/ZukkoWidgetSdk.md`. Open work: `TODO.md` (local only, gitignored).

## Owner rules (follow exactly)

- **Language**: reply to the owner in Uzbek, short and plain. Code, comments, commits, docs: English.
- **Ask, don't guess**: if a request's scope is unclear, ask one short question before acting. Do only what was asked; never widen scope on your own.
- **Use agents, in parallel**: delegate implementation/research to the agents below; split independent work across several agents running in parallel, with non-overlapping files.
- **After every change**: `flutter analyze --fatal-infos` must be clean and `flutter test` must pass. Tests must be real (fail when the logic breaks).
- **Packages**: always the latest stable version; adapt the code to new APIs instead of staying on an old major. Check with `flutter pub outdated`.
- **Store safety**: don't add packages that inject storage/media permissions (`READ_MEDIA_*`, `READ/WRITE_EXTERNAL_STORAGE`, `MANAGE_EXTERNAL_STORAGE`); no `permission_handler`. Use system pickers.
- **Naming**: everything a developer sees (package name, README/docs, public classes, screens/widgets, example app) says Zukko / ZukkoChat, never Chatwoot. Internal names and `lib/src` file names may stay. NEVER change Hive box name strings, the secure-storage key string, Hive typeIds/field indices.
- **Parallel sessions**: other sessions may have uncommitted changes in this repo; treat them as the baseline, don't revert or block on them.
- **Git ignore**: no junk in git (build outputs, IDE/OS files, secrets, root `pubspec.lock`, `TODO.md`).

## Git

- NEVER commit or push without the owner's explicit instruction.
- Commit message: one line, English: `<type>(<scope>): AA - <subject>` (e.g. `fix(realtime): AA - rewrite websocket client with reconnect`). Types: feat, fix, refactor, build, test, docs, chore, ci.
- When asked to commit: split the changes into several commits by type of change.
- NEVER add Claude as co-author: no `Co-Authored-By`, no "Generated with Claude Code".
- Every change gets a note in `CHANGELOGS/YYYY-MM-DD_<kebab-slug>.md` (`# Title` + What / Why or Symptom / Root cause / Fix). `CHANGELOG.md` is the pub.dev release log — separate.

## Agents

Delegate IMPLEMENT / RESEARCH work via the Agent tool, picked by topic:

| Agent | Use for |
|---|---|
| `Senior Developer` | Complex implementation |
| `Mobile App Builder` | Flutter / iOS / Android work |
| `Software Architect` | Design, architecture decisions |
| `Backend Architect` | API design, server contract |
| `Code Reviewer` | Code review, edge cases |
| `AI-Generated Code Security Auditor` | Security audit |
| `API Tester` | Endpoint contract validation |
| `Test Automation Engineer` | Tests, flake elimination |
| `Minimal Change Engineer` | Smallest diff, no scope creep |
| `Git Workflow Master` | Commits, history cleanup |
| `Codebase Onboarding Engineer` | Tracing unfamiliar code |
| `UI Designer` / `UX Architect` | Visual design, design systems |
| `Accessibility Auditor` | a11y audit |
| `Performance Benchmarker` | Performance |

Trivial one-line edits may be done directly.

## Commands

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # *.g.dart are gitignored: run after clone / model changes
flutter analyze --fatal-infos
flutter test
cd example && flutter analyze && flutter test
dart pub publish --dry-run
```

## Key facts

- Public entrypoint: `lib/zukko_chat_flutter.dart` (exports only); `lib/src/` is internal. Main API: `ZukkoChatClient.create(baseUrl, websiteToken, user?)`, screen `ZukkoChat(options: ZukkoChatOptions(...))`, `zukkoChatSignOut`.
- Session: `POST /config` (JWT + pubsub token) -> `PATCH /contact/set_user` (HMAC `identifier_hash`; 401 fails closed). JWT lives only in the AES-encrypted Hive contact box; never logged.
- Realtime: ActionCable `/cable`, `RoomChannel` + `pubsub_token`; reconnect refetches `GET /messages?after=<id>`.
- UI: 3 styles in `lib/src/ui/chat/styles/<name>/` (smooth_silk, minimal_clean, thread_feed); shared widgets in `components/`; styles never import data/client. Fonts bundled in `assets/fonts/` (Regular + SemiBold only). l10n: en, ru, uzLatn, uzCyrl, tr, kaa.
- Tests: `test/` mirrors `lib/src/`; hand-written fakes; `test/utils/fake_chat_server.dart` mirrors the real server — keep it faithful.
- Example app id: `ai.zukko.chat.sdk`.
