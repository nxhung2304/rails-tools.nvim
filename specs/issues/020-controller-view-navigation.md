## **Status:**
- Review: Approved
- PR: Draft

## Metadata
- **Title:** Controller-View Navigation
- **Phase:** Phase 2 — Expansion v0.7
- **GitHub Issue:** #52

---

## Description
Jump between a controller action and its views, and open the files related to the current
file (helper, model, layout, schema, fixture, migration).

Steps:
- Tell what kind of Rails file the current buffer is (controller, view, model, migration, helper)
- Switch between a controller action and its view with one key
- List the related files of the current file, or open one type directly
- Ask before creating a missing action view

Scope comes from `specs/story.md` L4-020. The `:R` command was dropped at spec review
(see Key Decisions).

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/controller_view.lua`
- Shared path helpers: `lua/rails-tools/core/rails_paths.lua` (moved out of `core/gf.lua`, see
  "Shared helpers")
- Command: `:Rails related [type]`, registered in `commands.lua`
- Keymap: `<leader>rv` → `controller_view.toggle()`
- Menu item: "Related Files" → `controller_view.related_menu()`
- Command, keymap and menu item only when `modules.controller_view = true`. With the module off,
  `:Rails related` warns `Rails: controller-view navigation is disabled, set modules.controller_view = true`.

### File kinds
Decided from the path relative to the Rails root of the current file:

| Kind | Path | Parts |
|---|---|---|
| controller | `app/controllers/<path>_controller.rb` | `path` (e.g. `admin/users`) |
| view | `app/views/<folder>/<file>` | `folder`, action = `<file>` up to the first `.`; partial when it starts with `_`; layout when `folder` starts with `layouts` |
| model | `app/models/<path>.rb`, not under `app/models/concerns/` | `path` (e.g. `admin/user`) |
| migration | `db/migrate/*.rb` | |
| helper | `app/helpers/<path>_helper.rb` | `path` |

Anything else has no related files: `Rails: no related files for this file`.

### Related types per kind

| Kind | Types |
|---|---|
| controller | view, helper, model, layout |
| view | controller, helper, model, layout |
| model | controller, schema, fixture, migration |
| migration | model |
| helper | controller |

How each type is found (paths relative to the Rails root):
- **view** (from controller): views of the action at the cursor (see "Controller → view");
  no action at the cursor → every file in `app/views/<path>/`.
- **controller**:
  - from a view: `app/controllers/<folder>_controller.rb` at `def <action>` (line 1 for a partial);
    no controller → `app/mailers/<folder>.rb` at `def <action>`; a layout view has no controller.
  - from a model: `app/controllers/<pluralize(path)>_controller.rb`.
  - from a helper: `app/controllers/<path>_controller.rb`.
- **helper**: `app/helpers/<path or folder>_helper.rb`.
- **model** (from a controller or view): `singularize` of the last segment; try
  `app/models/<namespace>/<singular>.rb` first, then `app/models/<singular>.rb`.
  From a migration: the first table argument of the first `create_table` / `change_table` /
  `add_column` / ... line in the file (same method table as `019-context-aware-gf.md`), mapped to a
  model with `rails_paths.model_file_for_table`.
- **layout**: `app/views/layouts/<path or folder>.*`, else `app/views/layouts/application.*`,
  html format first, engines in `view.priority` order.
- **schema**: `db/schema.rb` at the `create_table "<table>"` line (`core/schema.lua` already parses
  the line number). No `db/schema.rb` → `Rails: schema not found: db/schema.rb`
  (`db/structure.sql` is not supported).
- **fixture**: `test/fixtures/<table>.yml`, then `spec/fixtures/<table>.yml`.
- **migration**: every `db/migrate/*.rb` with a schema statement on the table (`create_table`,
  `change_table`, `drop_table`, `add_column`, `add_index`, `add_reference`, ... — the method table of
  019 — whose table argument is `<table>`), newest first.
- **Table of a model**: the annotate `# Table name:` line in the model file, else
  `model_context.pluralize(<model file base name>)`.

### Controller → view
- Action = the nearest line above or at the cursor matching `def <name>`. No action when:
  - there is no such line, or
  - a line `private` / `protected` (alone on its line) comes before that `def`, or the `def`
    line itself starts with `private` / `protected`.
- Views of an action: `rails_paths.view_candidates(root, <path>, <action>, "html")` — html first,
  then format-less files, engines in `view.priority` order, other formats after.
- One view → open it. Several → `vim.ui.select`. None → ask
  `Create app/views/<path>/<action>.html.<engine> ? (y/N): ` (engine = `view.engine` when not
  `"auto"`, else the first of `view.priority`); `y` creates the folders and an empty file and
  opens it, anything else does nothing.

### toggle() (`<leader>rv`)
- In a controller → `to_view()`.
- In a view → `from_view()`.
- Anywhere else → `Rails: not a controller or view`.

### related_menu() (`:Rails related`, menu "Related Files")
- `vim.ui.select` over every related file that exists, labelled `<type>: <path>`
  (`view: app/views/users/show.html.erb`). Several migrations or views → one entry each.
- No related file exists → `Rails: no related files for this file`.

### :Rails related <type>
- Unknown type → `Rails: usage: :Rails related [view|controller|helper|model|layout|schema|fixture|migration]`.
- Type not in the current kind's list → `Rails: no <type> for this file`.
- One file → open it (at its line when it has one). Several → `vim.ui.select`.
- Not found → `Rails: <type> not found: <first path tried>`; for `view`, the create prompt above.

### Shared helpers (`core/rails_paths.lua`)
Moved from `core/gf.lua` (approved at spec review) so both modules use the same lookup; gf
behaviour does not change and its tests stay as they are.
```lua
M.relative_path(root, file)                       -- path under root, or file unchanged
M.format_of(relative_file)                        -- "html" when the name has no format part
M.default_engine()                                -- view.engine when not "auto", else view.priority[1], else "erb"
M.view_candidates(root, folder, base, format)     -- ordered paths of app/views/<folder>/<base>.*
M.model_file_for_table(root, table_name)          -- annotate "# Table name:" first, else app/models/<singular>.rb
M.fixture_file(root, name)                        -- test/fixtures then spec/fixtures, nil when missing
M.migration_arguments(line)                       -- leading symbol/string arguments, each with kind "table" | "reference" | nil
```
`model_context.pluralize(word)` is added next to `singularize`: `y` after a consonant → `ies`;
`s`, `x`, `z`, `ch`, `sh` → `es`; else `s`.

### Public API (`core/controller_view.lua`)
```lua
M.TYPES                                   -- { "view", "controller", "helper", "model", "layout", "schema", "fixture", "migration" }
---@return RailsFileKind|nil
M.kind_of(relative_file)
---@return string|nil
M.action_at(lines, lnum)                  -- public action at or above the cursor
---@param ctx {root, relative_file, lines, cursor_lnum}
---@return RelatedEntry[], RelatedMissing|nil
M.find(ctx, type)                         -- files of one type; why nothing was found
---@return RelatedEntry[]
M.related(ctx)                            -- every existing related file, in type order
M.to_view()
M.from_view()
M.toggle()
M.related_menu()
M.open_type(type)
```

---

## Acceptance Criteria
- [x] `to_view()`: controller action at the cursor → its view; several → pick; none → ask to create
- [x] `views_for_controller()`: cursor outside an action → every view of the controller
- [x] `from_view()`: view → controller at `def <action>`; mailer views → mailer
- [x] Related files: helper, model, layout, schema, fixture, migration
- [x] `from_migration()`: migration → model of the first table it creates/changes, listed in `related_menu()`
- [x] `related_menu()` lists only related files that exist
- [x] View engine order follows `view.engine` / `view.priority` (erb, haml, slim)
- [x] Format: html first, then format-less views
- [x] Namespaced controllers (`admin/users`) map to `app/views/admin/users/`
- [x] Prompt to create a missing action view
- [x] Only active when `modules.controller_view = true`

---

## Implementation Checklist
- [x] Create `lua/rails-tools/core/rails_paths.lua`; move the shared helpers out of `core/gf.lua`
- [x] Add `pluralize()` to `core/model_context.lua`
- [x] Create `lua/rails-tools/core/controller_view.lua` (kinds, related types, toggle, menu, open_type, create prompt)
- [x] Register `:Rails related [type]` in `commands.lua`
- [x] Register keymap `<leader>rv` (gated by `modules.controller_view`)
- [x] Add "Related Files" menu item (gated by `modules.controller_view`)
- [x] Create `tests/core/rails_paths_spec.lua` and `tests/core/controller_view_spec.lua`
- [x] Extend command, keymap, menu and `model_context` tests
- [x] Update README and `specs/story.md`

---

## Key Decisions
- **No `:R` command.** The project rule is that every subcommand goes through `:Rails`.
- **`<leader>rv` toggles controller ↔ view**; the other related files go through `:Rails related`.
- **Private actions are not actions**: a `def` after `private` / `protected` has no view.
- **Mailer views** fall back to `app/mailers/<folder>.rb` because they also live in `app/views`.
- **Table name**: annotate `# Table name:` first, else a simple `pluralize`.
- **Model → migration lists every migration that touches the table**, newest first, not only
  `*_create_<table>.rb`, so later column changes are reachable.
- **Schema** opens `db/schema.rb` at the table; `structure.sql` is not supported.
- **Shared helpers move to `core/rails_paths.lua`** instead of being copied; gf's tests guard the move.
- **Create prompt only for a missing action view**, same wording as `core/alternate.lua`.

---

## Notes
- Known limits: irregular plurals (`person` → `persons`, not `people`); a model namespaced by a
  module with `table_name_prefix` is mapped to the table of its base name unless annotate says otherwise;
  nested `def` inside a block or `class << self` counts as an action.
- `030-gf-constant-stub-generator.md` (#34) is unrelated to this module.

---

## Decision Log
- 2026-11-18: Design settled in discussion (10 questions, all accepted as recommended) — see Design and Key Decisions above
- 2026-11-18: Public API settled as `kind_of` / `action_at` / `find` / `related` and `rails_paths.migration_arguments` during implementation — see Public API above
