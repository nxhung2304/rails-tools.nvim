# Implement plan — L1-013 Terminal Abstraction Layer

Source specs: `specs/issues/002-terminal-abstraction.md`, `specs/story.md` (section "Default Configuration Structure" → `terminal` is the source of truth for config values).

## Goal
Create `lua/rails-tools/ui/terminal.lua`: one module that runs a command in a terminal window and can toggle / send text to it, backed by either `toggleterm.nvim` or a native Neovim terminal. Console (L3-011) and Runner (L3-012) will call it later.

## Scope
- Create `lua/rails-tools/ui/terminal.lua`.
- Create `tests/ui/terminal_spec.lua`.
- Then tick the L1-013 boxes in `specs/story.md` and `specs/issues/002-terminal-abstraction.md` (Step 5).

## Do NOT touch
- `lua/rails-tools/config.lua` — `terminal` defaults already exist (`provider`, `direction`, `float.width/height`, `horizontal.size`, `vertical.size`). Do not add keys.
- `lua/rails-tools/commands.lua`, `init.lua`, `keymaps` — nothing registers a command or keymap for the terminal in this task. Console/Runner do that later.
- `lua/rails-tools/utils.lua` (empty, leave as is).
- Existing tests. Do not edit or weaken them.
- No comments in code (project rule). LuaDoc (`---@param`, `---@return`) on every public function only.
- No global state: file-local `state` table inside the module is fine.
- `toggleterm.nvim` and `telescope` must stay optional: never `require("toggleterm")` at module top level; always `pcall`.

## Public API

```lua
---@class RailsToolsTerminalOpts
---@field direction? "float"|"horizontal"|"vertical"  overrides config.terminal.direction
---@field cwd? string                                  defaults to Rails root, then cwd

M.resolve_provider() -> "toggleterm"|"native"
M.open(cmd, opts)    -- cmd: string|nil. nil = interactive shell
M.toggle()
M.send(text)         -- text: string
```

- Read config via `require("rails-tools.config").get().terminal` at call time (not at require time), so `setup()` overrides apply.
- `cwd` default: `require("rails-tools.detectors.rails").root()` or `vim.loop.cwd()` (same fallback style as `core/alternate.lua` `project_root`).
- Notify with `vim.notify("Rails: <message>", vim.log.levels.WARN)` — keep the `Rails: ` prefix used in `commands.lua`.

## Behaviour

### Provider resolution — `M.resolve_provider()`
| `config.terminal.provider` | Result |
|---|---|
| `"native"` | `"native"` |
| `"toggleterm"` | `"toggleterm"` if `pcall(require, "toggleterm.terminal")` succeeds, else warn once-per-call and return `"native"` (graceful degrade, never error) |
| `"auto"` (default) | `"toggleterm"` if the pcall succeeds, else `"native"` |
| anything else | treat as `"auto"` |

### Single active terminal
The module keeps exactly one terminal. `M.open` when one already exists: close/shut it down first, then open the new one (replaces it). This keeps `toggle()` and `send()` unambiguous.

### Native backend
State: `state = { bufnr = nil, winid = nil, job_id = nil }`.

- Window per direction (current window layout is not otherwise changed):
  - `float`: `vim.api.nvim_open_win(bufnr, true, { relative = "editor", style = "minimal", border = "rounded", width = math.floor(vim.o.columns * float.width), height = math.floor(vim.o.lines * float.height), col = <centered>, row = <centered> })`. Center with `math.floor((vim.o.columns - width) / 2)` and `math.floor((vim.o.lines - height) / 2)`.
  - `horizontal`: `vim.cmd("botright " .. horizontal.size .. "split")` then set the new buffer in that window.
  - `vertical`: `vim.cmd("botright " .. vertical.size .. "vsplit")` then set the new buffer in that window.
  - Fixed split sizes: `horizontal.size` = rows, `vertical.size` = columns. Set `winfixheight` / `winfixwidth` on the respective split.
- Create the buffer with `vim.api.nvim_create_buf(false, true)`, set it as the window's buffer, then start the terminal **in that window** (`vim.api.nvim_win_call` or while it is current):
  - Use `vim.fn.termopen(cmd or vim.o.shell, { cwd = cwd })` (works on Neovim 0.9+). If `vim.fn.has("nvim-0.11") == 1`, `termopen` is deprecated — use `vim.fn.jobstart(cmd or vim.o.shell, { cwd = cwd, term = true })` instead. Wrap this choice in one small local function `start_job(cmd, cwd)` returning the job id.
  - Store `bufnr`, `winid`, `job_id` in `state`.
  - `vim.cmd("startinsert")` after opening.
- `toggle()`:
  - window valid (`vim.api.nvim_win_is_valid(state.winid)`) → `vim.api.nvim_win_close(state.winid, false)`; keep buffer + job alive; set `state.winid = nil`.
  - window closed but buffer valid (`vim.api.nvim_buf_is_valid(state.bufnr)`) → reopen a window for the same buffer with the same direction logic (extract a local `open_window(bufnr, direction)` shared with `open`), update `state.winid`, `startinsert`.
  - neither → `vim.notify("Rails: no terminal to toggle", WARN)`.
- `send(text)`:
  - no live job (`state.job_id == nil` or buffer invalid) → `vim.notify("Rails: no active terminal", WARN)` and return.
  - else `vim.fn.chansend(state.job_id, text .. "\n")`. Append `"\n"` only if `text` does not already end with it.
- When the job exits / buffer is wiped: clear `state` (use a `TermClose`/`BufWipeout` autocmd on `state.bufnr` with `once = true`), so `toggle()`/`send()` don't act on dead state.

### Toggleterm backend
Use `require("toggleterm.terminal").Terminal`. **Verify method names against the toggleterm.nvim README/source before relying on them** (author could not check: toggleterm is not installed locally). Expected shape:

```lua
local Terminal = require("toggleterm.terminal").Terminal
state.term = Terminal:new({
  cmd = cmd,
  dir = cwd,
  direction = direction,
  hidden = true,
  close_on_exit = false,
  float_opts = { width = ..., height = ... },
})
state.term:open(size)
```

- `size`: `horizontal.size` for horizontal, `vertical.size` for vertical, `nil` for float.
- Float `width`/`height` are absolute cells in toggleterm: compute the same way as native: `math.floor(vim.o.columns * float.width)` / `math.floor(vim.o.lines * float.height)`.
- `toggle()` → `state.term:toggle()`; if no `state.term` → same warning as native.
- `send(text)` → `state.term:send(text)`; if no `state.term` → "no active terminal" warning. If `state.term:send` is not the right call in the installed version, use `vim.fn.chansend(state.term.job_id, ...)`.
- Replacing an existing terminal: `state.term:shutdown()` before creating the new one.
- `cmd == nil` → omit `cmd` so toggleterm uses the default shell.

### Dispatch
`M.open/toggle/send` call `resolve_provider()` each time and route to the native or toggleterm local functions. Do not cache the provider choice. A terminal opened by one provider is toggled/sent by the same provider that created it (store `state.provider` at open and route `toggle`/`send` by it, not by re-resolving), so a config change mid-session cannot desync.

### Direction validation
Unknown direction (config or opts) → fall back to `"float"` (default). No error.

## Tests — `tests/ui/terminal_spec.lua`
plenary `describe/it`, same style as `tests/core/alternate_spec.lua`. Reset between tests: `package.loaded["rails-tools.ui.terminal"] = nil` and `package.loaded["rails-tools.config"] = nil`, re-`require` in `before_each`; close any leftover windows/buffers in `after_each` (`vim.cmd("silent! %bwipeout!")`).

Toggleterm is not installed in the test env → fake it with `package.preload["toggleterm.terminal"]` returning a table `{ Terminal = { new = ... } }` whose instance records `open/toggle/send/shutdown` calls. Remove the preload and `package.loaded["toggleterm.terminal"]` in `after_each`.

Cases:
1. `resolve_provider`: `"native"` → `"native"` even when toggleterm is faked.
2. `"auto"` with toggleterm faked → `"toggleterm"`; without → `"native"`.
3. `"toggleterm"` configured but not installed → returns `"native"`, no error thrown.
4. Unknown provider string behaves as `"auto"`.
5. Native `open("echo hi")` float: a floating window exists (`vim.api.nvim_win_get_config(win).relative == "editor"`), buffer `buftype == "terminal"`.
6. Native float size: width/height equal `math.floor(vim.o.columns * 0.8)` / `math.floor(vim.o.lines * 0.8)` with defaults; and honour overrides via `config.setup({ terminal = { float = { width = 0.5, height = 0.5 } } })`.
7. Native `horizontal`: window height == `horizontal.size` (default 15, and an override of 10); window is at the bottom (`vim.fn.winnr("j") == vim.fn.winnr()`-style check or compare `win_screenpos` row greater than the editor window's).
8. Native `vertical`: window width == `vertical.size` (default 80, and an override); window is right of the original one.
9. `opts.direction` overrides `config.terminal.direction`.
10. Unknown direction falls back to float.
11. `toggle()` with window open closes the window but the buffer stays valid; second `toggle()` reopens a window showing the same buffer.
12. `toggle()` with no terminal → warns, no error (stub `vim.notify` and assert message contains `"no terminal"`).
13. `send("echo hello")` with a live native terminal: wait with `vim.wait(2000, function() ... end)` until the buffer lines contain `hello`.
14. `send()` with no terminal → warns, no error.
15. `open()` twice keeps only one terminal: the first buffer is no longer valid/listed, the second is.
16. `cmd == nil` opens the default shell (terminal buffer exists, no error).
17. Toggleterm backend: with fake + provider `"toggleterm"`, `open("rails console")` calls `Terminal:new` with `cmd = "rails console"` and the right `direction`; horizontal passes `horizontal.size` to `open`; `toggle()` and `send("x")` reach the fake; calling `toggle()` after a config change to `"native"` still goes to the fake (provider pinned at open).
18. `cwd` option: `open("pwd", { cwd = <tmp dir> })` (native) → buffer text eventually contains that dir name.

Tests must not depend on a real Rails project, toggleterm, or network.

## Step — Verify
```bash
make test-file FILE=tests/ui/terminal_spec.lua
make test
make lint
```
All must pass, no new luacheck warnings. Existing tests must stay green with no edits.

Note: the `Makefile` `test` target passes `minimal_init='tests/minimal_init.lua'` but that file does not exist in the repo; if `make test` fails for that reason alone, report it and do not fix it in this task.

## Step 5 — Update checkboxes
- `specs/story.md` L1-013: tick every item, remove the `⚠️ NEEDED BY ...` marker from the heading, add to "Completed Items", update the Layer 1 progress row (3 → 4 of 4, 100%), remove "Implement L1-013" from "Next Steps" and renumber.
- `specs/issues/002-terminal-abstraction.md`: tick all Acceptance Criteria and Implementation Checklist items.

## Notes / risks
- `story.md` lists `float = { width, height }` as ratios (0.8) — the spec file's "Float opts: width=0.8" agrees. Treat values `<= 1` as ratios; do not add absolute-cell support.
- toggleterm API names above are from memory, not verified in this repo → check before use (see Toggleterm backend).
- `termopen` vs `jobstart({ term = true })` split exists only because of the Neovim 0.9+ minimum; the dev machine runs Neovim 0.13-dev.
- `story.md` says Console/Runner depend on this module; they must call only `open/toggle/send`. Do not export `state`.
