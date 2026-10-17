# doc/ is local only

## What
`doc/` (Develop.md, FlutterClientSdk.md, ZukkoWidgetSdk.md) is now in `.gitignore` and `.pubignore` and was untracked with `git rm -r --cached doc`; the files stay on disk. CLAUDE.md notes that `doc/` is local only.

## Why
Owner: the internal docs (a detailed map of the Zukko Chat server API, local paths) must not be visible on GitHub or pub.dev. Nothing in the package or dartdoc depends on them. Older commits still contain them (history not rewritten).
