[ISSUE-#55] setup() marks itself done before sub-modules finish, so a failed setup cannot be retried
GitHub Issue: #55
State: OPEN
Labels: bug
Assignees: 
Source: GitHub

## Problem
`setup_done = true` is set before any sub-module runs. If one of them throws (bad user config, a module bug), every later `setup()` call returns immediately and the plugin stays half-initialised until Neovim restarts.

## Evidence
- `lua/rails-tools/init.lua:12-15` sets the flag first, then `init.lua:17-24` runs config, commands, keymaps, schema, gf, lsp, cmp and telescope setup.

## Acceptance criteria
- [ ] `setup_done` is only set after all sub-module setups succeed (or the failure is reported and a retry is possible).
- [ ] A second `setup()` after a successful one is still a no-op.
- [ ] Regression test: force one sub-module to error, fix it, call `setup()` again and check it runs.
