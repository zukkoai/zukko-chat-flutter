# Keep CHATWOOT-BACKEND.md out of the pub package

## Symptom
A history/secret audit before going public found that `dart pub publish --dry-run` included `CHATWOOT-BACKEND.md` (local backend requirements, lists open server weaknesses) in the package archive.

## Root cause
`.pubignore` replaces `.gitignore` for publishing; the file was only in `.gitignore`.

## Fix
Added `CHATWOOT-BACKEND.md` to `.pubignore`. Dry-run: 0 warnings, 427 KB, file no longer listed.
