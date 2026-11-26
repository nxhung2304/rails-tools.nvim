[ISSUE-#54] modules.schema = false does not disable schema cache, LSP K/gd override and cmp source
GitHub Issue: #54
State: OPEN
Labels: bug
Assignees: 
Source: GitHub

## Problem
`setup()` always calls `core.schema.setup()`, `integrations.lsp.setup()` and `integrations.cmp.setup()`, no matter what `modules.schema` is set to. A user who sets `modules.schema = false` still gets the save autocmd, the `K`/`gd` override in Ruby buffers and the `rails_schema` cmp source.

## Evidence
- `lua/rails-tools/init.lua:21-24` — the three calls have no config check.
- `grep -rn "modules.schema" lua/` finds no reader of this flag (only health and menu read the modules table generically).
- Compare `core/gf.lua:456`, which does return early when `modules.gf` is false.

## Related: Telescope `grape` picker ignores `modules.grape`
`:Telescope rails grape` (and `require("telescope").extensions.rails.grape`) runs even when `modules.grape = false`. `lua/rails-tools/telescope/init.lua:31-33` exports it without a module check, while `:Rails grape` does check (`commands.lua:39`).

## Acceptance criteria
- [ ] With `modules.schema = false`: no `rails_tools_schema_cache` / `rails_tools_lsp_schema` augroup is created, `K`/`gd` are not remapped, and the cmp source is not registered.
- [ ] Default (`modules.schema = true`) behaviour unchanged.
- [ ] With `modules.grape = false`, the Telescope `grape` picker is not exported (or shows the same "disabled" warning as `:Rails grape`).
- [ ] Regression tests covering both flags.
