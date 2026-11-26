[ISSUE-#59] K and gd are always overridden in Ruby buffers, with no way to opt out
GitHub Issue: #59
State: OPEN
Labels: enhancement
Assignees: 
Source: GitHub

## Problem
On every `LspAttach` for ruby/eruby, the plugin maps `K` and `gd` buffer-locally, deferred with `vim.schedule` so it always wins over the user's own `on_attach` mappings. Users who map these keys to something else (another picker, a different hover) lose their mapping, and there is no config option to turn this off or change the keys.

## Evidence
- `lua/rails-tools/integrations/lsp.lua:66-108` — `attach_hover` / `attach_goto_definition` set `K` and `gd` unconditionally; the comment at `lsp.lua:100-104` explains the `vim.schedule` is meant to override `on_attach`.
- `config.lua` has no option for these keys.

## Acceptance criteria
- [ ] Config option to disable the override or choose the keys (e.g. `lsp = { hover = "K", definition = "gd" }`, `false` to skip).
- [ ] When the user already has a non-default buffer mapping on the key, it is kept (or the chosen behaviour is documented).
- [ ] The Rails-aware hover/definition stay reachable as functions so users can map them themselves.
- [ ] Regression test for enabled, disabled and custom-key cases.
