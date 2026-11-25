---
GitHub Issue: #12
Status: READY
---

## Summary
The three entry points (string, prompt, visual selection) and the config key are clear. Open points: where output goes (terminal vs notification), how code is quoted for the shell, empty/cancelled input, non-Rails projects, and how `:Rails runner {code}` gets its argument through the dispatcher.

## Well-Defined
- Module path and `run(code)`, `run_prompt()`, `run_visual()`
- Command from `config.runner.command` (default "rails runner")
- `:Rails runner {code}` and `:Rails runner` (no args = prompt)

## Issues Found
### Output target is ambiguous
> Display output in terminal or notification / Uses vim.notify for quick results

**Problem:** The spec allows both and does not say which to use when.
**Suggest:** Follow the checklist ("Integrate with ui/terminal.lua"): always run in the terminal. stdout and errors stay visible there. Drop the notification path.

### Shell quoting
> Execute via `rails runner`

**Problem:** Code with quotes, `$` or newlines breaks or changes meaning if concatenated as is.
**Suggest:** Build `<runner.command> <vim.fn.shellescape(code)>`.

### Empty / cancelled input
> (not covered)

**Suggest:** `run("")` or whitespace only → WARN "no code to run", no terminal. Cancelled prompt (nil) → do nothing.

### Non-Rails project
> (not covered)

**Suggest:** Same as console: WARN notify, no terminal.

### Dispatcher does not pass arguments
> Register `:Rails runner {code}` subcommand

**Problem:** `commands.lua` calls `handler()` with no arguments, so the code after `runner` is lost.
**Suggest:** Pass the command `opts` to the handler (existing handlers ignore it). The runner handler takes the raw text after `runner` from `opts.args`, so spacing and quotes in the code are kept.

### Visual selection entry point
> `runner.run_visual()` executes visual selection

**Problem:** No command/keymap triggers it in this issue; `:Rails` has no range support.
**Suggest:** Implement and test `run_visual()` from the last visual selection (`'<`, `'>`, `visualmode()`); wiring it to a keymap belongs to L3-009.

## Score (6/10)
- AC: ✅
- Checklist: ❌
- Design: ❌

## Status
- [x] READY — all "Suggest" items adopted during implementation
- [ ] PENDING — needs clarification
