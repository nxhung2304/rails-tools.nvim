[ISSUE-#58] Rails detector caches "not a Rails project" forever
GitHub Issue: #58
State: OPEN
Labels: bug
Assignees: 
Source: GitHub

## Related
- [Fix direction](./implement.md)

## Problem
The detector caches results per directory, including negative results, and never clears them. If Neovim is opened in a directory before `bin/rails` exists (e.g. before `rails new` finishes), or the result changes later, that directory keeps reporting "not Rails" until Neovim restarts.

## Evidence
- `lua/rails-tools/detectors/rails.lua:39-41` returns the cached value whenever `cache[start_dir] ~= nil`.
- `rails.lua:50` stores `false` for a miss.
- No invalidate function exists in `lua/rails-tools/detectors/` (grep `invalidate`). `grape.lua` and `test_framework.lua` use the same module-level cache pattern.

## Acceptance criteria
- [ ] Negative results are not cached, or are re-checked (e.g. on `DirChanged` or after a short TTL).
- [ ] A public way to clear the detector cache exists and is documented.
- [ ] Regression test: detect in an empty dir, create `Gemfile` + `bin/rails`, detect again and get the root.
