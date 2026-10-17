# CLAUDE.md is local only

## What
`CLAUDE.md` added to `.gitignore` and untracked with `git rm --cached` (the file stays on disk). It was already in `.pubignore`.

## Why
Owner: internal agent/owner rules and local paths must not be visible on GitHub. Older commits still contain it (history not rewritten).
