## **Status:**
- Review: Approved
- PR: Draft

## Metadata
- **Title:** Plugin Entry Point
- **Phase:** Phase 1 — MVP v0.3 (tracked as `L1-Entry` in `specs/story.md`,
  no dedicated issue file existed until now)
- **GitHub Issue:** #30

---

## Description
Every feature built so far (`detectors`, `core/alternate`, and
`021-schema-inspector.md`'s `core/schema`/`integrations/lsp`/
`integrations/cmp`) is a standalone, tested Lua module — but nothing
actually loads or activates them for a real user. There is no
`require("rails-tools")`, no `:Rails` command, no lazy-load registration.
The README's own Installation section (`require("rails-tools").setup()`)
currently errors, since `lua/rails-tools/init.lua` doesn't exist.

This issue is the connective tissue: a `setup()` a user's config can
actually call, a `:Rails` command dispatcher other features register
into, and the `plugin/` file lazy.nvim/packer/vim-plug expect.

Steps:
- `init.lua` exposes `M.setup(user_config)`: merge config (via
  `config.lua`, deep-extended), then call each already-built feature's own
  `setup()`/attach point that needs one (currently just
  `integrations/lsp.lua` and `integrations/cmp.lua` from
  `021-schema-inspector.md`)
- `commands.lua` registers a single `:Rails {subcommand} {args}` user
  command with a dispatch table (per `CLAUDE.md`'s convention: one
  `nvim_create_user_command`, not one per feature)
- `plugin/rails-tools.lua` is the thin file Neovim auto-sources that just
  guards against double-setup; actual `setup()` is still called
  explicitly by the user's plugin manager config (per the README's
  `lazy.nvim` example), matching how most Neovim plugins work
- `utils.lua` holds anything shared across 2+ modules that isn't
  Rails-detection-specific (e.g. path helpers) — audit
  `core/alternate.lua`'s local `relpath()` as a candidate to move here

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/init.lua`
- Module: `lua/rails-tools/commands.lua`
- Module: `lua/rails-tools/utils.lua`
- File: `plugin/rails-tools.lua`
- Depends on `lua/rails-tools/config.lua` existing as the single source of
  config truth (`001-config-system.md` — currently `config.lua` has a
  `mappings` table but no `setup()`/`get()`/defaults; `core/alternate.lua`
  also still hardcodes its own copy of the mapping table instead of
  reading `config.lua`, which this issue should fix while wiring
  `alternate` into `commands.lua`)

---

## Acceptance Criteria
- [x] `require("rails-tools").setup(opts)` does not error with no `opts`
      (zero-config) and deep-merges a user-supplied `opts` over defaults
- [x] `setup()` calls `integrations/lsp.lua` and `integrations/cmp.lua`'s
      `setup()` (from `021-schema-inspector.md`) so `K`/`gd`/completion
      actually activate for a real user — this is the acceptance
      criterion that unblocks `021-schema-inspector.md` end-to-end
- [x] `:Rails alternate` runs `core/alternate.lua`'s existing logic
- [x] `:Rails` with no subcommand does not error (menu itself is
      `010-menu.md`'s scope — a plain message/no-op is fine for now)
- [x] An unknown subcommand (`:Rails bogus`) shows a clear error, not a
      Lua traceback
- [x] `plugin/rails-tools.lua` does not force-load anything eagerly beyond
      what the user's `ft = {"ruby", "eruby"}` lazy-load spec (per README)
      already implies
- [x] Calling `setup()` twice does not double-register the `:Rails`
      command or double-attach the `LspAttach` autocmd from
      `integrations/lsp.lua`

---

## Implementation Checklist
- [x] Create `lua/rails-tools/init.lua`
- [x] Implement `M.setup(opts)`
- [x] Wire `integrations/lsp.lua`'s `setup()` into `M.setup()`
- [x] Wire `integrations/cmp.lua`'s `setup()` into `M.setup()`
- [x] Create `lua/rails-tools/commands.lua`
- [x] Implement `:Rails` user command with subcommand dispatch table
- [x] Register `alternate` subcommand (calls `core/alternate.lua`)
- [x] Create `lua/rails-tools/utils.lua`
- [x] Move `core/alternate.lua`'s `relpath()` here if it turns out to be
      needed elsewhere too (don't move it speculatively otherwise) — not
      needed elsewhere yet, left in place; `utils.lua` created empty for
      now
- [x] Create `plugin/rails-tools.lua`
- [x] Fix `core/alternate.lua` to read mappings from `config.lua` instead
      of its own hardcoded copy (see `001-config-system.md`)
- [x] Guard `setup()` against being called twice
- [x] Create `tests/init_spec.lua`
- [x] Create `tests/commands_spec.lua`
- [x] Test zero-config `setup()`
- [x] Test config merging (user opts override defaults)
- [x] Test `:Rails alternate` dispatch
- [x] Test unknown subcommand error handling
- [x] Test double-`setup()` doesn't double-register

---

## Notes
- This is the last piece blocking `021-schema-inspector.md`'s hover/cmp/gd
  from actually working for anyone who isn't manually calling
  `require("rails-tools.integrations.lsp").setup()` themselves
- Menu (`010-menu.md`), keymaps (`011-keymaps.md`), and most other
  `:Rails {subcommand}` entries stay out of scope here — this issue only
  needs to prove the dispatch table pattern works for one real
  subcommand (`alternate`) and be trivially extensible for the rest
- Was tracked only as `L1-Entry` in `specs/story.md` (no issue file)
  before this issue was created; `specs/story.md` should be updated to
  point `L1-Entry` at `029-plugin-entry-point.md` once this is filed
