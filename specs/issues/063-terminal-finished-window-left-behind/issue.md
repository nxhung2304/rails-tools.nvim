[ISSUE-#63] Terminal: a finished command's window and buffer are left behind when the next command opens
GitHub Issue: #63
State: OPEN
Labels: bug
Assignees: 
Source: GitHub

## Related
- [Fix direction](./implement.md)

## Problem
When the command in the plugin terminal exits (runner, spec, generate, console quit), the plugin forgets that terminal, but its window and buffer stay on screen. The next command then opens a new terminal without closing the old one:
- float: the new float is stacked on top of the old one
- split: a new split is added each time
- `toggle` reports "no terminal to toggle" while the old window is still visible

## Reproduce
Native provider, headless:
```
nvim --headless -u NONE --cmd "set rtp+=." -c "lua local t=require('rails-tools.ui.terminal'); require('rails-tools.config').setup({terminal={provider='native'}}); t.open('echo one',{cwd='/tmp'}); vim.wait(1000); vim.cmd('stopinsert'); t.open('echo two',{cwd='/tmp'}); vim.wait(1000); local n=0; for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].buftype=='terminal' then n=n+1 end end; io.stdout:write('terminal bufs='..n..' wins='..#vim.api.nvim_list_wins()..'\n')" -c "qa!"
```
Result: `terminal bufs=2 wins=3` (expected 1 terminal buffer, 2 windows).

## Evidence
- `lua/rails-tools/ui/terminal.lua:75-84` — native `TermClose` calls `clear_state()` while the buffer and window still exist.
- `terminal.lua:131-135` — toggleterm `on_exit` does the same.
- `terminal.lua:191-196` — `M.open` only closes the previous terminal through `state`, which is already empty.

## Acceptance criteria
- [ ] After a command exits, opening the next command reuses or closes the previous terminal window and buffer (native and toggleterm).
- [ ] `toggle` / `show` still work on a terminal whose process has exited.
- [ ] `confirm_replace` still only asks when a job is actually running.
- [ ] Regression test based on the reproduce script above.
