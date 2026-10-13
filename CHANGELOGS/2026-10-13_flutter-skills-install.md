# Flutter and Dart skills installed (project-local)

## What
- Source: GitHub `alisheraxmedov/flutter-skills`, commit `11d765487f13bec98c8bd35f34ba15e97d67e9ab`.
- Installed all skills of both plugins (`dart/` and `flutter/`) as plain copies into `.claude/skills/` (39 dirs), via `npx skills add <local clone> --skill ... --agent claude-code --copy` (no `-g`).
- Dirs: dart, async, data-model, dart-analyze, dart-optimization, dart-test, flutter, flutter-analyze, flutter-optimization, flutter-test, accessibility, animation, app-size, ci-cd, custom-paint, deep-linking, error-handling, firebase, flavors-env, forms, graphql, i18n, image-assets, isolates-background, layout, migrations, navigation, networking, observability, packaging, persistence, platform-channels, push-notifications, release, responsive, review, security, state-management, theming.
- Renames: both plugins have `analyze`, `optimization`, `test`. They were renamed to `dart-<x>` / `flutter-<x>`, and the frontmatter `name:` in those 6 SKILL.md files was set to the folder name.
- Reference rewrites: every `dart:<skill>` / `flutter:<skill>` skill reference in the .md files was rewritten to the installed folder name (e.g. `flutter:state-management` -> `state-management`, `dart:analyze` -> `dart-analyze`). Dart library imports (`import 'dart:async';`, `dart:io`, `dart:ffi`, ...) were left untouched.
- `skills-lock.json` was deleted (it pointed at temp paths and its hashes no longer matched).

## Why
- The plugins' `dart:`/`flutter:` namespaces only exist when installed as Claude Code plugins. That would also enable their hooks and cache files globally, so a project-local copy was chosen.
- Router skills (`flutter`, `dart`) reference sibling skills, so all siblings are installed and the references point at real folder names.

## Note
- Hooks (`flutter/hooks/`) were NOT installed.
- To update: re-clone the repo, re-copy `dart/skills/*` and `flutter/skills/*` into `.claude/skills/`, re-apply the three renames per plugin, the 6 `name:` fixes and the reference rewrites above.
- Skill files also tell the agent to open replies with a "Using ..." marker and end with a "Check:" list; this is their built-in output style.
