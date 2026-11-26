[ISSUE-#60] Default commands mix `rails` and `bin/rails`
GitHub Issue: #60
State: OPEN
Labels: enhancement
Assignees: 
Source: GitHub

## Problem
Routes use `bin/rails routes`, while console, runner and generators use plain `rails ...`. Plain `rails` depends on a global gem on PATH and may pick a different Rails version than the project's bundle; `bin/rails` is what Rails itself generates and recommends.

## Evidence
- `lua/rails-tools/config.lua:101` → `"bin/rails routes"`
- `config.lua:106` → `"rails console"`, `config.lua:109` → `"rails runner"`, `config.lua:112` → `"rails generate"`
- The detector already accepts `bin/rails` or `script/rails` (`detectors/rails.lua:20`), and health picks between them (`health.lua:124`).

## Acceptance criteria
- [ ] All default commands use the same Rails executable, preferring `bin/rails` when it exists in the project root, with a fallback for old apps.
- [ ] User-set commands are never changed.
- [ ] Docs/README updated with the default.
