[ISSUE-#64] cmp.dedupe_with_lsp never matches, and errors on Neovim 0.9
GitHub Issue: #64
State: OPEN
Labels: bug
Assignees: 
Source: GitHub

## Related
- [Implement plan](./implement.md)

## Problem
`cmp.dedupe_with_lsp = { "ruby_lsp" }` is meant to hide the `rails_schema` completion source when that LSP client is attached. It never does:
1. The whole list is passed as the `name` filter: `vim.lsp.get_clients({ bufnr = bufnr, name = names })`. Neovim compares `client.name == filter.name` as a string, so a table never matches and the check always returns "not covered".
2. On Neovim 0.9 (the plugin's documented minimum) `vim.lsp.get_clients` does not exist (only `get_active_clients`), so completion raises an error as soon as the option is set.

## Evidence
- `lua/rails-tools/integrations/cmp.lua:17`
- Neovim runtime `lua/vim/lsp.lua`: v0.10.4 line 778 and v0.11.5 line 1185 both use `client.name == filter.name`.
- Neovim 0.9.5 runtime only defines `lsp.get_active_clients` (`lua/vim/lsp.lua:1850`).
- `tests/integrations/cmp_spec.lua:28-80` replaces `vim.lsp.get_clients` with a fake, so the existing tests cannot catch either problem.

## Acceptance criteria
- [ ] Each configured name is checked separately (or clients are filtered by name in Lua).
- [ ] Works on Neovim 0.9 (`get_active_clients` fallback) and 0.10+.
- [ ] Tests attach a real (dummy) LSP client instead of replacing `vim.lsp.get_clients`, and run on the minimum supported Neovim version.
