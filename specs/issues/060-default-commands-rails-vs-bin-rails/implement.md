# Implement plan — BF-060 One Rails executable for all default commands

## Decisions made without you
- Open question 1 (fallback for apps without `bin/rails`) answered with the recommendation: `script/rails`. It matches the detector and health, and the detector guarantees it exists when `bin/rails` does not.
- Open question 2 (nil defaults vs `"bin/rails ..."` strings) answered with the recommendation: nil, resolved at run time. It is the only way to never change a user-set value while still falling back.
- Open question 3 (fix `routes` for Rails 3 apps via `rake routes`) answered with the recommendation: no, out of scope; file a follow-up only if someone reports it.
- README keeps the command override examples commented out inside the copy-paste `setup({...})` block, so copying the block does not turn the defaults into user values and lose the `script/rails` fallback.
- Defaults for `routes.command`, `console.command`, `runner.command`, `generators.command` become nil (removed from `M.defaults`). The command is built at run time from the project root.
  - Reason: with a string default the plugin cannot tell "user typed `rails console`" from "default `rails console`", so any fallback would also rewrite a user value. Nil means "not set by the user".
- Executable choice: `bin/rails`, unless the root has `script/rails` and no `bin/rails` (Rails 3 apps), then `script/rails`. No root -> `bin/rails`.
  - Matches what the detector already accepts (`detectors/rails.lua:20`) and what health reports (`health.lua:124`); the detector guarantees one of the two exists for any detected root.
- `health.lua:124` keeps its own check (no refactor), even though it now duplicates the new helper.

Source: `specs/issues/060-default-commands-rails-vs-bin-rails/issue.md` (GitHub #60), `specs/story.md:405-408` (BF-060).

## Description
- Defaults mix executables: `config.lua:101` `"bin/rails routes"`, `:106` `"rails console"`, `:109` `"rails runner"`, `:112` `"rails generate"`.
- Every reader of these values (grep `\.command` in `lua/`, no other reader):
  - `core/console.lua:11` (`console_command()`, used to open the terminal at `:48` and to compare with `terminal.active_cmd()` at `:18`)
  - `core/runner.lua:70`
  - `core/generators.lua:41`
  - `core/routes.lua:294-295`
  - `integrations/grape.lua:290` (runs the listing script) and `:318` (error message)
- Every one of those call sites already has the project `root` in scope and already requires `rails-tools.detectors.rails`.
- `console.toggle` calls `is_console_active(project_root())`, where `project_root()` can return nil (`console.lua:21-32`, `:59`), so the resolver must accept a nil root.

## Design
- `detectors/rails.lua`: new `M.executable(root)` -> `"script/rails"` when `root` is set, `root/bin/rails` is not readable and `root/script/rails` is readable; otherwise `"bin/rails"`.
- `config.lua`:
  - Remove `command` from `routes`, `console`, `runner`, `generators` defaults (keep `routes.args`, `routes.cache_ttl`; the other three sections stay as empty tables so `config.get().console` etc. still exist).
  - Add constant `RAILS_SUBCOMMANDS = { routes = "routes", console = "console", runner = "runner", generators = "generate" }`.
  - Add `M.rails_command(section, root)`: return `M.get()[section].command` when set, else `require("rails-tools.detectors.rails").executable(root) .. " " .. RAILS_SUBCOMMANDS[section]` (require inside the function, same lazy pattern as optional modules).
- Each call site replaces `config.get().<section>.command` with `config.rails_command("<section>", root)`. No other logic changes.
- User-set commands: returned unchanged, including a user value equal to an old default such as `"rails console"`.

## Acceptance Criteria
- [ ] With `bin/rails` in the root and no user config: console, runner, generators, routes and Grape listing all run `bin/rails <subcommand>`.
- [ ] Root with only `script/rails`: all of them run `script/rails <subcommand>`.
- [ ] A user-set `command` for any of the four sections is used exactly as given.
- [ ] README states the default and the fallback.
- [ ] Regression tests below added; `make test` and `make lint` pass.

## Implementation Checklist
1. `lua/rails-tools/detectors/rails.lua`: add constants `BIN_RAILS = "bin/rails"`, `SCRIPT_RAILS = "script/rails"` after `local M = {}`, and before `return M`:
   ```lua
   ---@param root string|nil
   ---@return string
   function M.executable(root)
     if root and not file_exists(root, BIN_RAILS) and file_exists(root, SCRIPT_RAILS) then
       return SCRIPT_RAILS
     end
     return BIN_RAILS
   end
   ```
   Leave `find_root` (line 20) untouched.
2. `lua/rails-tools/config.lua`:
   - `routes`: remove `command = "bin/rails routes",`.
   - `console = {}`, `runner = {}`, `generators = {}` (remove their `command` lines).
   - Add `local RAILS_SUBCOMMANDS = { ... }` after `local M = {}`.
   - Add before `return M`:
     ```lua
     ---@param section "routes"|"console"|"runner"|"generators"
     ---@param root string|nil
     ---@return string
     function M.rails_command(section, root)
       local configured = M.get()[section].command
       if configured then
         return configured
       end
       return require("rails-tools.detectors.rails").executable(root) .. " " .. RAILS_SUBCOMMANDS[section]
     end
     ```
3. `lua/rails-tools/core/console.lua`: `console_command()` takes `root` and returns `config.rails_command("console", root)`; pass `root` at `:18` and `:48`.
4. `lua/rails-tools/core/runner.lua:70`: `config.rails_command("runner", root) .. " " .. vim.fn.shellescape(code)`.
5. `lua/rails-tools/core/generators.lua:41`: `config.rails_command("generators", root) .. " " .. trimmed_args`.
6. `lua/rails-tools/core/routes.lua:295`: `vim.trim(config.rails_command("routes", root) .. " " .. (routes_config.args or ""))`.
7. `lua/rails-tools/integrations/grape.lua` `load_routes`: `local runner_command = config.rails_command("runner", root)`; use it at `:290` and in the error message at `:318`. Today `runner.command` defaults to `"rails runner"` (`config.lua:109`), so `:318` works; once step 2 removes that default, `config.get().runner.command` is nil for users who did not set it, and `:318` would format nil and error unless it uses the resolved value.
8. Update existing tests whose expected string is the old default (intended spec change, list each in the final report):
   - `tests/core/runner_spec.lua:89, 140, 168, 187, 195, 206, 224, 232`: `rails runner` -> `bin/rails runner`.
   - `tests/core/generators_spec.lua:77, 83, 89, 103, 148`: `rails generate` -> `bin/rails generate`.
   - `tests/core/console_spec.lua:102, 150, 191`: `{ "rails console" }` -> `{ "bin/rails console" }` (all three run with no user console command). Leave `:136` and `:145` (`fake_terminal.active = "rails runner 'puts 1'"`) as they are: they only stand for "another terminal is active".
   - `tests/config_spec.lua:68`: `current.routes.command` is now nil; assert `assert.is_nil(current.routes.command)` and keep the `cache_ttl` assertion.
   - Checked: no other test asserts an old default. `tests/core/routes_spec.lua` (`:75`, `:389`) and `tests/integrations/grape_spec.lua` (`:55-61`) always set their own command; `tests/ui/terminal_spec.lua` passes `"rails console"` / `"rails runner"` straight to `terminal.open` and does not read config. Re-check with `grep -rn "rails console\|rails runner\|rails generate\|rails routes" tests/` before running `make test`.
9. New tests:
   - `tests/detectors/rails_spec.lua`, `describe("executable")`: `bin/rails` only -> `"bin/rails"`; `script/rails` only -> `"script/rails"`; both -> `"bin/rails"`; nil root -> `"bin/rails"`.
   - `tests/config_spec.lua`: `rails_command("console", root)` with `bin/rails` root -> `"bin/rails console"`; `rails_command("generators", root)` with `script/rails` root -> `"script/rails generate"`; `rails_command("routes", root)` -> `"bin/rails routes"`; after `setup({ console = { command = "rails console" } })` -> `"rails console"` (user value kept even with `bin/rails` present).
   - `tests/core/runner_spec.lua`: project with only `script/rails` -> `opened[1].cmd == "script/rails runner 'puts 1'"`.
   - `tests/core/console_spec.lua`: `setup({ console = { command = "bundle exec rails console" } })` -> opened is `{ "bundle exec rails console" }`.
   - `tests/integrations/grape_spec.lua`: new case next to "reports a command that cannot be started without erroring" (`:327`). The shared `before_each` (`:111`) always sets `runner.command` through `use_runner_command` (`:55-61`), so this case must first call `config.setup({ finder = { provider = "native" } })` (no `runner` key) to drop the user runner command. Stub `vim.fn.jobstart` to return `-1`, call `grape.show()` under `pcall`, assert it returned true, `notifications[2].level == vim.log.levels.ERROR` and `notifications[2].msg` contains `bin/rails runner` (proves `:290`/`:318` use the resolved default and do not format nil).
10. `README.md` Configuration block (a copy-paste `setup({...})` block, "Override only what you need"): add before `keymaps`, with every override line commented out so copying the block keeps the run-time default and the `script/rails` fallback:
    ```lua
      -- Rails commands default to bin/rails (script/rails when the app has no bin/rails).
      -- Set a full command to override, e.g.:
      -- console    = { command = "bundle exec rails console" },
      -- runner     = { command = "bundle exec rails runner" },
      -- generators = { command = "bundle exec rails generate" },
      -- routes     = { command = "bundle exec rails routes" },
    ```
    and `README.md:121` "via `rails runner`" -> "via `bin/rails runner`".
11. Run `make test` and `make lint`.
12. `specs/story.md`:
    - Tick BF-060 items at `:406-408`.
    - Default-config block `:584-606`: remove `command = "bin/rails routes",` from `routes` (keep `args`, `cache_ttl`), make `console`, `runner`, `generators` empty tables (`console = {},` etc., keeping their section comments), and add one line above `routes`: `-- command for routes/console/runner/generators: not set by default; built at run time as bin/rails <subcommand> (script/rails when the app has no bin/rails)`.
    - Check: `grep -n "rails console\|rails runner\|rails generate\|bin/rails routes" specs/story.md` shows no default-config lines.
    - Tick the acceptance criteria in `issue.md`.

## Risks to test
- `make test` fails if any test still asserts an old default (`rails console` at `console_spec.lua:150`, `:191` was missed in the first draft). Covered by step 8 and its grep check.
- Grape `:318` nil-format crash only shows with no user runner command; the shared `before_each` always sets one. Covered by the step 9 Grape case that drops the user runner command.
- README copy-paste block pinning the executable for users who copy it. Covered by step 10 (override lines commented out); review the README diff.
- `specs/story.md:584-606` default-config block left stale. Covered by step 12 and its grep check.
- Console reuse: `is_console_active` compares `terminal.active_cmd()` with the resolved command for the current root. Open console, hide it, run `:Rails console` again: expect the same terminal shown, not a replace prompt. Covered by existing console tests once step 8 strings are updated.
- `bin/rails` without the executable bit (e.g. cloned on a filesystem that drops it): `bin/rails console` fails where global `rails console` worked. Behaviour change by design; user can set the command.
- Users who relied on the global `rails` gem (no `bin/` in repo but `script/rails` absent): cannot happen, the detector requires one of the two.
- Merge conflict with BF-059 (#59, same story group) only if it also edits `config.lua` defaults; whichever merges second rebases and reruns `tests/config_spec.lua`.

## Notes
- Do NOT touch: `health.lua`, `find_root`, `rspec.command`, terminal code. No new comments in code.
- LuaDoc that becomes inaccurate (NOT edited, flag in the final report): `generators.lua:22` "(default `rails generate`)"; `runner.lua` doc lines "with `rails runner`" on `run_prompt` / `run_visual`.
- Assumption (from Rails knowledge, not verified in this repo): Rails 3 has no `rails routes` subcommand (`rake routes` until Rails 5), so `script/rails routes` still fails on Rails 3 apps. It failed before this change too (`bin/rails routes` default). Out of scope.

## Open questions
- None. All three were answered with the recommended option; see "Decisions made without you".

Review: Approved
