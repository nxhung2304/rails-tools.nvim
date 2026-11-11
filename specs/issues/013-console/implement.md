# Implement plan — L3-011 Rails Console

Source specs: `specs/issues/013-console.md`, `specs/story.md` (L3-011).

## Goal
`:Rails console` opens an interactive Rails console in the terminal abstraction (`ui/terminal.lua`), and `console.toggle()` hides/shows the same console session without restarting it.

## Scope
- Create `lua/rails-tools/core/console.lua` with `M.open()` and `M.toggle()`.
- Register `console` in the `subcommands` table of `lua/rails-tools/commands.lua`.
- Add two read-only accessors to `lua/rails-tools/ui/terminal.lua` (see "Terminal change").
- Tests: `tests/core/console_spec.lua`, new cases in `tests/ui/terminal_spec.lua` and `tests/commands_spec.lua`.
- Tick L3-011 in `specs/story.md` and `specs/issues/013-console.md`.

## Do NOT touch
- `config.lua`: `console.command` already exists (default `"rails console"`).
- Existing terminal behaviour (open/toggle/send) and existing tests.
- No keymap (L3-009) and no menu entry (L3-008) in this task.
- No new comments in code; LuaDoc on public functions, `---@param`/`---@return` on locals like sibling files.

## Terminal change (additive only)
`ui/terminal.lua` keeps exactly one terminal. Console needs to know whether that terminal is the console, otherwise `toggle()` would hide/show whatever the Runner (L3-012) opened last, and `open()` would kill a running console session.
- Store the command passed to `M.open(cmd, opts)` in `state.cmd`; `clear_state()` resets it.
- `M.active_cmd()` → `state.cmd` while a terminal exists (`state.provider ~= nil`), else `nil`.
- `M.is_visible()` → native: `state.winid` is valid, on the current tabpage and still shows the terminal buffer; toggleterm: `state.term:is_open()`.
- `M.show()` → open a window for the running terminal in the current tab without closing other windows (native: `open_window(state.bufnr, direction)`; toggleterm: `state.term:open()`); no terminal → warn "Rails: no terminal to show".
- toggleterm: pass `on_exit` to `Terminal:new` and clear state when the exiting terminal is still the active one (native already clears on `TermClose`).

## Behaviour — `core/console.lua`
- `command` = `config.get().console.command`, read at call time.
- Console is "active" when `terminal.active_cmd() == command`.
- `M.open()`:
  - Not in a Rails project (`detectors.rails.root()` is nil) → `vim.notify("Rails: not a Rails project", WARN)` and return. Running `rails console` outside a project only shows a shell error.
  - Console active and visible → do nothing.
  - Console active but not visible here → `terminal.show()` (same session, current tab).
  - Otherwise → `terminal.open(command)` (cwd defaults to the Rails root inside `terminal.open`).
- `M.toggle()`: console active and visible → `terminal.toggle()` (hide); otherwise `M.open()`.
- `:Rails console` → `M.open()`.

## Tests
`tests/core/console_spec.lua` — stub `rails-tools.ui.terminal` via `package.loaded` with a fake recording `open/toggle/active_cmd/is_visible`; Rails project fixture in a temp dir (Gemfile + bin/rails), `cd` in and back.
1. `open()` with no console → `terminal.open("rails console")`.
2. Custom `console.command = "bundle exec rails c"` → opened with that command.
3. `open()` when console active and hidden → `toggle()` called, `open()` not called.
4. `open()` when console active and visible → neither called.
5. `open()` when another command (runner) is active → `terminal.open(console command)`.
6. `toggle()` when console active → `terminal.toggle()`.
7. `toggle()` with no console → opens it.
8. Outside a Rails project → warns, no terminal call.
9. Integration (real native terminal, `console.command = "cat"`): `open()` creates a terminal buffer; `toggle()` hides the window; second `toggle()` shows the same buffer (session kept).

`tests/ui/terminal_spec.lua`: `active_cmd()` nil before open, equals cmd after open, nil after the buffer is wiped; `is_visible()` true after open, false after toggle; toggleterm fake with `is_open`.

`tests/commands_spec.lua`: `:Rails console` dispatches to `core/console.lua` `open()`.

## Risks (risk-issue, before coding)
- R1 — Shared single terminal. Console and Runner (L3-012) share `ui/terminal.lua`'s single terminal (`ui/terminal.lua:6-12`, `M.open` shuts down the previous one at :170-175). Opening the runner kills a running console. Accepted for this task: the terminal design is a one-terminal model; changing it belongs to the terminal module. Console at least never kills its own session (open checks `active_cmd`).
- R2 — Identity by command string. If `console.command` changes while a console runs, the old console is no longer recognised and `open()` replaces it. Low impact; accepted.
- R3 — Exited console. When the user types `exit`, `TermClose` clears terminal state (`ui/terminal.lua:71-81`) so the next `open()` starts a fresh console; the native "[Process exited]" buffer stays listed. Existing terminal behaviour, not changed here.
- R4 — toggleterm `is_open()`, `open()` and the `on_exit` option are assumed from toggleterm.nvim's Terminal API; toggleterm is not installed in the test env, so only a fake is tested. Verify with toggleterm installed.
- R5 — Only Neovim 0.9.5 is available in the test environment; the native terminal on 0.11+ uses `jobstart(..., { term = true })` (existing code path), not covered here.
