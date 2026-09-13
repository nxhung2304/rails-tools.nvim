## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Schema Inspector
- **Phase:** Phase 3 — Polish v0.8
- **GitHub Issue:** #28

---

## Description
Implement the schema data layer and use it to power ActiveRecord-attribute-
aware editor features: hover documentation, `nvim-cmp` completion, and
go-to-definition — since none of those are real Ruby methods an LSP can see.

> Table-structure browsing (a `:Rails schema {table}` command + Telescope
> picker) is a separate, independent feature built on top of this same
> parser. It is **not** required for hover/completion/gd to work and has
> been split out to
> [028-schema-display.md](028-schema-display.md) so this issue can ship
> without waiting on command/UI/Telescope work.

Steps:
- Parse `db/schema.rb` as the canonical, always-up-to-date source of
  columns/types/indexes per table
- Also parse the `annotate` gem's schema comment block in each
  `app/models/**/*.rb` file, when present, and map `model → table`
  from its `# Table name: xxx` line
- Merge: column list/types come from `db/schema.rb`; when a model file has
  an annotate block for a column, **prefer jumping to that comment line**
  over `db/schema.rb` (annotate lives right next to the code the dev is
  reading; `db/schema.rb` is the fallback when annotate is absent/stale)
- Expose the parsed data to:
  - Hover (`K`) on `receiver.column` or a bare `column` inside the owning
    model — show type/constraints instead of LSP's "No information available"
  - `nvim-cmp` source — complete attribute names after `receiver.`,
    scoped to the inferred model (not every column in the project)
  - Go-to-definition (`gd`) on a column — jump to the annotate comment line
    if present, else the `db/schema.rb` column line, else the
    `create_table` line

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/schema.lua` — parsing + cache, returns per
  table: `{ columns = { name = { type, signature, indexes } }, source }`
- Module: `lua/rails-tools/core/annotate.lua` — parses one model file's
  annotate comment block into `{ table_name, columns = { name = {
  signature, lnum, col } } }`
- Module: `lua/rails-tools/core/model_context.lua` — receiver → model
  inference shared by hover/cmp/gd (done — see Implementation Checklist):
  - `self` / bare identifier (no receiver) → model of the current buffer
    (only valid inside `app/models/**/*.rb`)
  - `<var>.column` → camelize/singularize `<var>`, match against known
    model names; on no match, fall back to the current buffer's model
    (never a project-wide "every model with this column" guess) unless the
    lookup itself has no receiver context at all (see completion below)
- Integration: `lua/rails-tools/integrations/cmp.lua` — registers the
  `rails_schema` cmp source (gated by `modules.schema` / cmp being present)
- Integration: hover and `gd` are wired in the existing LSP `on_attach`
  path, buffer-local for `ruby`/`eruby`, falling back to
  `vim.lsp.buf.hover()` / `vim.lsp.buf.definition()` when no schema match
- Config: `modules.schema` (default `true` — this is core Rails ergonomics,
  not an optional integration like rspec/grape)

---

## Acceptance Criteria
- [x] Parses `db/schema.rb` (columns, types, indexes) as the primary source
- [x] Parses `annotate` schema comment blocks in `app/models/**/*.rb`
      (column signatures + `# Table name:` → model/table mapping)
- [x] Model inference handles: `self`, bare identifier (current buffer's
      own model only), `snake_case_var`, simple pluralization
      (`users` → `User`)
- [x] Hover (`K`) on `receiver.column` / bare `column` inside its own model
      shows the column's type + full signature (default/null/etc.), not
      "No information available"
- [x] Hover falls back to normal LSP hover when the identifier isn't a
      known column for the resolved model
- [x] `nvim-cmp` source completes column names after `receiver.`, scoped to
      the model inferred from `receiver` — never lists columns from
      unrelated models that happen to share the same column name
- [x] `gd` on a column jumps to, in priority order: (1) the annotate
      comment line in the owning model file, (2) the matching line in
      `db/schema.rb`, (3) the `create_table` line if the column is
      implicit (`id`, `created_at`, `updated_at`)
- [x] `gd`/hover fall back to `vim.lsp.buf.definition()` /
      `vim.lsp.buf.hover()` for anything that isn't a recognized column

---

## Implementation Checklist
- [x] Create `lua/rails-tools/core/schema.lua` (db/schema.rb parser +
      cached, annotate-merged `resolve()`)
- [x] Create `lua/rails-tools/core/annotate.lua` (annotate block parser:
      signatures + table name + comment line location, per model)
- [x] Create `lua/rails-tools/core/model_context.lua` (receiver → model
      inference, reused by hover/cmp/gd)
- [x] Create `lua/rails-tools/cache.lua` (generic TTL cache; did not exist
      before this issue) and integrate it into `core/schema.lua`'s
      `resolve()`/`invalidate()`
- [x] Create `lua/rails-tools/integrations/cmp.lua` (`rails_schema` source)
- [x] Create `lua/rails-tools/integrations/context.lua` (cursor →
      receiver/word parsing, shared by hover and `gd`)
- [x] Create `lua/rails-tools/integrations/lsp.lua` — `hover_lines()` /
      `definition_location()` (the actual logic, root/model injectable for
      testing) plus `setup()`, which wires `K`/`gd` via a native
      `LspAttach` autocmd for ruby/eruby buffers (not the user's own
      lspconfig `on_attach` — keeps this zero-config/portable)
- [ ] Call `integrations/lsp.lua`'s and `integrations/cmp.lua`'s `setup()`
      from the plugin entry point once it exists (blocked on `init.lua` /
      `plugin/rails-tools.lua` — see `001-config-system.md`); until then
      an early adopter can call both manually
- [x] Create `tests/core/schema_spec.lua`
- [x] Create `tests/core/annotate_spec.lua`
- [x] Create `tests/core/model_context_spec.lua`
- [x] Create `tests/integrations/context_spec.lua`
- [x] Create `tests/integrations/lsp_spec.lua`
- [x] Test schema.rb parsing
- [x] Test annotate block parsing (signature + table name + line location)
- [x] Test model inference (self, bare word, var name, pluralization,
      unresolvable → current-buffer-model-only, never project-wide)
- [x] Test cmp completion scoping (no cross-model leakage) — covered at
      the `hover_lines`/`definition_location` layer both cmp and hover/gd
      share; a dedicated `cmp`-source-level test would need to mock
      `nvim-cmp`'s callback, not just this layer
- [x] Test gd priority order (annotate → schema.rb column → create_table)

---

## Notes
- Caches schema and annotate parsing for performance (TTL, keyed by Rails
  root via `cache.lua`; invalidate with `schema.invalidate(root)`)
- Supports both schema.rb and migrations as documented sources for the
  underlying table data, but annotate comments (when present) win for
  the actual jump target since they sit next to the code being read
- Bare-identifier (no receiver) lookups must **only** resolve against the
  current buffer's own model — this was a real bug during prototyping:
  treating every bare word as "show every model with a matching column"
  caused false positives outside model files. Covered by
  `lsp_spec.lua`'s "cross-model column name collisions" tests.
- `model_context.infer_model` returns `nil` outright for a `nil` receiver
  (by design — see its own tests); `integrations/lsp.lua`'s
  `resolve_column()` handles the bare-identifier case itself by using the
  current buffer's model directly instead of going through `infer_model`
- A model with no annotate block at all has no known table name (we don't
  attempt a full pluralization inverse of `singularize`), so it gets no
  `db/schema.rb` data merged in — its `known_models` entry still exists
  (for `model_context` purposes) but its `columns` table is empty
- Table-structure display + `:Rails schema` command + Telescope picker:
  see [028-schema-display.md](028-schema-display.md)
