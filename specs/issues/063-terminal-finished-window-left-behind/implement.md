# Implement plan — BF-063 Finished terminal left behind

## Related
- [Original issue](./issue.md)

Source: `issue.md` (GitHub #63), `specs/story.md:415-419` (BF-063).

## Root cause (confirmed)
- Native: `setup_cleanup` registers one `once` autocmd for `TermClose` and `BufWipeout` that calls `clear_state()` (`lua/rails-tools/ui/terminal.lua:74-84`). When the job exits, `bufnr`/`winid`/`provider` are dropped while the buffer and window stay on screen.
- Toggleterm: `on_exit` calls `clear_state()` (`terminal.lua:135-139`), same effect; `state.term` is lost, so `shutdown()` is never called on it.
- `M.open` closes the previous terminal only through `state` (`terminal.lua:185-190`), which is already empty → old buffer/window stay.
- `M.toggle` / `M.show` check `state.provider` (`terminal.lua:256-293`) → "no terminal to toggle" while the old window is visible.
- Reproduced on main with the issue script: `terminal bufs=2 wins=3`.

## Fix
- On process exit, forget only the command (`state.cmd = nil`); keep `bufnr`, `winid`, `provider`, `term`, `job_id`.
- Full `clear_state()` only on `BufWipeout` (native). Split the shared autocmd in two, because with `once = true` a fired `TermClose` removes the `BufWipeout` handler too.
- Why `state.cmd = nil` and not "keep everything": `console.lua:17` decides "console still active" from `active_cmd()`. If the command stayed after `rails console` exits, `:Rails console` would just show the dead terminal instead of starting a new console. Clearing `cmd` keeps today's behaviour there and keeps the existing toggleterm test "clears the active command when the toggleterm job exits" valid. The native backend has no such test today (its closest one is "clears the active command when the terminal buffer is wiped"), so step 3 adds one.
- Effects (checked with a prototype in a scratch copy, not in the repo):
  - Next `open` deletes/shuts down the old terminal through the existing code → issue script prints `terminal bufs=1 wins=2`.
  - `toggle` hides and re-shows the exited terminal (`wins` 2 → 1 → 2).
  - `is_running()` is false after exit (`jobwait` returns non -1), so `confirm_replace` does not ask.
  - Full `make test` passes with the change.
- No change to `M.open`, `toggle`, `show`, `is_running`, `confirm_replace`, `active_cmd`, `clear_state`, or callers (`runner.lua`, `rspec.lua`, `generators.lua`, `console.lua`).

## Implementation Checklist
1. `lua/rails-tools/ui/terminal.lua` `setup_cleanup` (lines 74-84): replace the single autocmd with two, both `buffer = bufnr, once = true`, both guarded by `if state.bufnr == bufnr`:
   - `"TermClose"` → `state.cmd = nil`
   - `"BufWipeout"` → `clear_state()`
2. Same file, toggleterm `on_exit` (lines 135-139): inside `if state.term == exited_term then`, replace `clear_state()` with `state.cmd = nil`.
3. `tests/ui/terminal_spec.lua`, `describe("native backend")`, add:
   - `it("clears the active command when the native job exits")`: `terminal.open("true", { cwd = vim.fn.getcwd() })` → `vim.fn.jobwait({ vim.b.terminal_job_id }, 5000)` → `vim.wait(2000, function() return terminal.active_cmd() == nil end)` → assert `terminal.active_cmd()` is nil and `terminal.is_visible()` is still true (buffer/window kept).
   - `it("closes the finished terminal when the next command opens")`: record the window count first (`local wins_before = #vim.api.nvim_list_wins()`, taken before any open) → `terminal.open("echo one", { cwd = vim.fn.getcwd() })` → record `first_buf` → `vim.fn.jobwait({ vim.b.terminal_job_id }, 5000)` → wait until `terminal.active_cmd()` is nil (`vim.wait(2000, ...)`, TermClose is async) → `terminal.open("echo two", ...)` → assert `first_buf` invalid, exactly 1 buffer with `buftype == "terminal"`, window count = `wins_before + 1`.
   - `it("toggles a terminal whose process has exited")`: open `"true"`, wait as above → `terminal.toggle()` → assert `is_visible()` false and no "no terminal to toggle" notify (stub `vim.notify`) → `terminal.toggle()` → assert `is_visible()` true.
   - `it("shows a terminal whose process has exited")`: open `"true"`, wait, `terminal.toggle()` to hide → `terminal.show()` → assert `is_visible()` true.
   - `it("replaces a finished terminal without asking")`: open `"true"`, wait → stub `vim.fn.confirm` to record a call → `confirm_replace()` returns true and confirm was not called.
4. Same file, `describe("toggleterm backend")`, add `it("shuts down a finished terminal when the next command opens")`: `terminal.open("rails runner")` → `local first_term = fake_term` → `terminal_args.on_exit(fake_term)` → `fake_term = vim.tbl_extend("force", {}, first_term)` → `terminal.open("rails console")` → assert `first_term.shutdown_called`.
5. Same describe, add `it("toggles a finished toggleterm terminal")`: open → `terminal_args.on_exit(fake_term)` → `terminal.toggle()` → assert `fake_term.toggled`.
6. Existing tests unchanged; all must keep passing (the two `on_exit` tests still hold: `active_cmd()` nil after exit; an old terminal's exit after replace does not touch the new state).
7. `make test`, `make lint`, then rerun the issue script → expect `terminal bufs=1 wins=2`.
8. Tick BF-063 items in `specs/story.md` and the acceptance criteria in `issue.md`.

## Risks to test
- Real toggleterm: assumption (toggleterm is not installed here, source not read) that `Terminal:shutdown()` on an already-exited job closes the window and deletes the buffer without error. Unit test only checks the call. Manual: with toggleterm installed, run `:Rails runner "puts 1"`, wait for exit, run it again → expect one terminal window.
- Native buffer closed by the user after exit (`:bd!` / keypress that wipes it): `BufWipeout` still clears state → next `toggle` warns as today. Covered by existing test "clears the active command when the terminal buffer is wiped".
- `console.open` after console exit: `active_cmd()` nil → `confirm_replace` true (not running) → `terminal.open` now also deletes the dead console buffer. Same flow as before plus the cleanup.
- Toggleterm only, guess (medium confidence; toggleterm source not read): `shutdown()` on an exited terminal whose buffer is already gone. Before, `on_exit` dropped `state.term`, so `shutdown()` never ran on an exited terminal; now every next command after a finished runner/spec/generate calls `state.term:shutdown()` (`terminal.lua:185-186`). If the user pressed a key after "[Process exited]" (Neovim wipes the buffer) or ran `:bd`, toggleterm still holds the old `bufnr` and the toggleterm path has no `BufWipeout` equivalent to clear state. Reachable in the current app. Manual (toggleterm not installed here): install toggleterm, `:Rails runner "puts 1"`, wait for exit, press a key to close it, run it again → expect no error and one terminal window.
- Toggleterm only, guess (low-medium confidence): `toggle`/`show` on an exited terminal may re-run the command. `state.term` is kept, and `M.toggle`/`M.show` call `term:toggle()`/`term:open()` (`terminal.lua:257-275`); if toggleterm's `open()` spawns a new job when the buffer is no longer valid, the command (e.g. `rails generate`) runs again. Not reachable from the current app UI (console toggles only while `cmd` is set), only through a direct API call. Manual (toggleterm not installed here): install toggleterm, run a command, close its buffer after exit, call `:lua require("rails-tools.ui.terminal").toggle()` → expect no new job/command run.
- `send()` to an exited terminal: `state.job_id` is now kept, so `chansend` to a closed channel errors instead of warning "no active terminal". Not reachable in the current app: no caller of `send` in `lua/` outside `terminal.lua` (grep `.send(`). Out of scope.

## Notes
- Do NOT touch: `M.open`, `toggle`, `show`, `is_running`, `confirm_replace`, callers. No new comments.
- The existing comment at `terminal.lua:184` "Shutdown existing terminal" stays accurate.

## Decisions made without you
1. A finished terminal is not reused in the same window; it is closed and a new one opened through the existing `M.open` path. Reason: reuse needs new window logic, out of scope.
2. `state.cmd` is cleared on exit (not kept). Reason: keeps `console` restart behaviour and the existing toggleterm exit test (see Fix).

Review: Approved
