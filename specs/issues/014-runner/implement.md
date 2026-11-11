# Implement plan — L3-012 Rails Runner

Source specs: `specs/issues/014-runner.md`, `specs/story.md` (L3-012).

## Goal
Run a Ruby snippet with `rails runner` from a string, a prompt or a visual selection, and show its output in the plugin terminal (`ui/terminal.lua`).

## Scope
- Create `lua/rails-tools/core/runner.lua` with `M.run(code)`, `M.run_prompt()`, `M.run_visual()`, `M.run_lines(line1, line2)` (added after review).
- `lua/rails-tools/commands.lua`: pass the rest of the command line and the range to subcommand handlers; register `runner`.
- Tests: `tests/core/runner_spec.lua`, new cases in `tests/commands_spec.lua`.
- Tick L3-012 in `specs/story.md` and `specs/issues/014-runner.md`.

## Do NOT touch
- `config.lua` (`runner.command` exists, default `"rails runner"`), `ui/terminal.lua`, `core/console.lua`.
- No keymap (L3-009) or menu entry (L3-008).
- No new comments; LuaDoc on public functions, `---@param`/`---@return` on locals like sibling files.

## Output decision
The spec allows "terminal or notification"; the checklist says "Integrate with ui/terminal.lua". Output goes to the terminal: `terminal.open(<runner.command> <shell-escaped code>, { cwd = root })`. Errors (Ruby exception, non-zero exit) are shown there with the backtrace and `[Process exited N]`. No `vim.notify` result path in this task.

## Behaviour — `core/runner.lua`
- `M.run(code)`:
  - `code` nil or only whitespace → `vim.notify("Rails: no code to run", WARN)`, return.
  - Not in a Rails project (`rails.root()` nil) → `vim.notify("Rails: not a Rails project", WARN)`, return (same wording as console).
  - Else `terminal.open(config.get().runner.command .. " " .. vim.fn.shellescape(code), { cwd = root })`. Read the command at call time.
- `M.run_prompt()`: `vim.ui.input({ prompt = "Rails runner: " }, fn)`; input nil (cancelled) → nothing; otherwise `M.run(input)` (empty input → the warning above).
- `M.run_visual()`: read the last visual selection from marks `'<` / `'>` and `vim.fn.visualmode()`:
  - `"v"`: first line from the start column, last line up to and including the last selected character (end mark is the byte start of that character; add its byte length via `matchstr(line, '\%<col>c.')` so multibyte characters are kept whole).
  - `selection=exclusive`: the end mark is one past the selection, so stop at the byte before it.
  - `"V"`: whole lines.
  - Block mode (Ctrl-V): warn "Rails: blockwise selection is not supported" and run nothing (decided after review).
  - Lines joined with `"\n"`, then `M.run(code)`.

## Commands
- Handler signature becomes `handler(opts)` with `opts = { args = <text after the subcommand, outer whitespace trimmed>, range, line1, line2 }`. Existing handlers ignore it.
- `:Rails` gets `range = true` so `:'<,'>Rails runner` works; other subcommands ignore the range.
- `:Rails runner {code}` → `run(code)` using the text after `runner` (inner quotes and spaces kept, outer whitespace trimmed).
- Range, no code: range equal to the last visual selection (`'<`/`'>` lines) → `run_visual()`; any other typed range → `run_lines(line1, line2)` (decided after review).
- `:Rails runner` (no range, no code) → `run_prompt()`.

## Tests
`tests/core/runner_spec.lua` — fake `rails-tools.ui.terminal` via `package.loaded`; Rails fixture in a temp dir.
1. `run("puts User.count")` → opens `rails runner 'puts User.count'` with `cwd = root`.
2. Custom `runner.command = "bin/rails runner"` → used.
3. Code with a single quote → shell-escaped (`'puts '"'"'hi'"'"''`).
4. Empty / whitespace code → warns, no terminal.
5. Outside a Rails project → warns, no terminal.
6. `run_prompt()`: stub `vim.ui.input` → runs the input; cancelled (nil) → nothing.
7. `run_visual()`: charwise selection across two lines; linewise selection; multibyte last character kept whole.
8. Integration: real native terminal with `runner.command = "echo"` → buffer shows the code.
`tests/commands_spec.lua`: `:Rails runner puts 1` → `run("puts 1")`; `:Rails runner` → `run_prompt()`; `:1,2Rails runner` → `run_visual()`; `:Rails alternate` still works.

## Risks (risk-issue, before coding)
- R1 — Single terminal. `terminal.open` replaces the active terminal (`ui/terminal.lua` `M.open`), so running a snippet ends a running Rails console. Same accepted model as L3-011; the PR states it.
- R2 — Range on `:Rails`. Adding `range = true` lets `:%Rails alternate` run without error (range ignored). Harmless; covered by the "alternate still works" test.
- R3 — `:'<,'>Rails runner` reads the marks of the last visual selection, which is what the range means here; `run_visual()` called from a keymap in visual mode before the marks are set (still in visual mode) would read the previous selection. Keymaps are L3-009's job; note it there.
- R4 — Shell escaping relies on `vim.fn.shellescape` for the user's `shell`; tested with the default `sh`. Unusual shells (fish, PowerShell) not tested.
- R5 — Only Neovim 0.9.5 in the test environment.
