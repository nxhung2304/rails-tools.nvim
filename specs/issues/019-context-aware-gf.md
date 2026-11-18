## **Status:**
- Review: Approved
- PR: Draft

## Metadata
- **Title:** Context-Aware gf
- **Phase:** Phase 2 — Expansion v0.7
- **GitHub Issue:** #50

---

## Description
Make `gf` understand Rails conventions. With the cursor on a partial name, a fixture,
a table name in a migration or a route helper, `gf` opens the Rails file it refers to.
Anywhere else, `gf` behaves exactly like Neovim's own `gf`.

Steps:
- Read the text under the cursor (or the visual selection) and the line around it
- Try each Rails resolver in order; the first one that recognizes the context wins
- Open the file (and line) it found, or say what was tried when the file is missing
- When no resolver recognizes the context, run Neovim's own `gf`

Scope comes from `specs/story.md` L4-019. Two items were removed at spec review
(see Key Decisions): Treesitter detection and "`User` → latest `*_create_users.rb`".

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/gf.lua`
- Wired from `init.lua` `setup()` with `require("rails-tools.core.gf").setup()`, which
  does nothing unless `modules.gf = true`
- No `:Rails` subcommand, no `<leader>r` keymap and no menu item: the key is `gf` itself

### Key mapping
- `setup()` creates a `FileType` autocmd for `ruby`, `eruby`, `haml`, `slim` and also
  attaches to already-loaded buffers of those filetypes.
- It sets buffer-local `gf` in normal mode and visual mode (`x`).
- Same approach as `integrations/lsp.lua` (buffer-local `K` / `gd` override).

### Resolvers (normal mode)
Tried in this order on the current line and cursor column. Each one either does not
recognize the context (next resolver), or recognizes it and returns a target.
Resolvers that need a Rails root get it from the current file (`detectors/rails.root`);
no root → no resolver matches → default `gf`.

1. **Partial** — the cursor is inside the quoted string argument of `render`:
   `render "shared/header"`, `render("header")`, `render partial: "header"`,
   `render(partial: "users/form", locals: { ... })`.
   - Name with `/` → `app/views/<dir>/_<name>.*`.
   - Name without `/`:
     - in a view `app/views/<dir>/...` → `app/views/<dir>/_<name>.*`
     - in a controller `app/controllers/<path>_controller.rb` → `app/views/<path>/_<name>.*`
     - elsewhere → not recognized
   - Format: taken from the current file name (`show.html.erb` → `html`,
     `index.json.jbuilder` → `json`, `feed.xml.builder` → `xml`); a controller or a file
     without a format → `html`. Candidates are files `_<name>.<format>.<engine>`; if none,
     `_<name>.html.<engine>` and `_<name>.<engine>` (no format part).
   - Engine: `view.engine` other than `"auto"` keeps only that engine. With `"auto"`,
     candidates are sorted by `view.priority` (`erb`, `haml`, `slim`), other engines
     (e.g. `jbuilder`) after them.
   - One candidate → open it. Several → `vim.ui.select` in that order. None → notify
     `Rails: partial not found: <first path tried>` and do nothing else.
2. **Fixture** — only in files under `test/` or `spec/` of the Rails root:
   - `fixtures :users, :posts` with the cursor on a symbol → that symbol's file.
     `fixtures :all` is not recognized.
   - `users(:alice)` with the cursor on `users` or `:alice` → the `users` file, cursor on
     the line `alice:` (first column). Recognized only when the fixture file exists, so
     ordinary method calls like `build(:user)` fall through.
   - Fixture file: `test/fixtures/<name>.yml`, then `spec/fixtures/<name>.yml`.
   - `fixtures :users` with no file → notify `Rails: fixture not found: test/fixtures/users.yml`.
   - The key `alice:` is not in the file → open the file at line 1 and notify
     `Rails: fixture alice not found in <file>`.
3. **Table → model** — only in files under `db/migrate/`, cursor on a symbol or string
   argument:
   - Reference argument → model by its singular name (`camelize`, file
     `app/models/<name>.rb`):
     `t.references :enrollment`, `t.belongs_to :enrollment`,
     second argument of `add_reference` / `remove_reference` / `add_belongs_to` /
     `remove_belongs_to`.
   - Table argument → model of the table:
     first argument of `create_table`, `change_table`, `drop_table`, `create_join_table`
     (both arguments), `rename_table` (both), `add_column`, `remove_column`, `change_column`,
     `change_column_default`, `change_column_null`, `rename_column`, `add_index`,
     `remove_index`, `add_reference`, `remove_reference`, `add_belongs_to`,
     `remove_belongs_to`, `add_timestamps`, `remove_timestamps`, `add_foreign_key` (both),
     `remove_foreign_key` (both).
     - Model lookup: the model whose annotate block says `# Table name: <table>`
       (each `app/models/**/*.rb` read with `core/annotate.parse`; `annotate.scan` is not
       used because it keys models by class name without namespace, so `admin/user.rb`
       and `user.rb` collide), else `app/models/<singularize(table)>.rb`
       (`core/model_context.singularize`).
   - Any other argument (e.g. the column `:email` in `add_column :users, :email`) is not
     recognized.
   - Recognized but the model file is missing → notify
     `Rails: model not found: app/models/<name>.rb`.
4. **Route helper** — the word under the cursor ends in `_path` or `_url`
   (`edit_user_path`, `users_url`, `main_app.root_path`):
   - Route name = the word without the suffix; find the route whose `name` equals it
     (non-engine routes first) and open it with `routes.goto_action(route)`.
   - Routes come from the routes cache. Cache empty → run the routes command async
     (shows `Rails: loading routes...`), then jump. Already loading → notify like
     `:Rails routes` does.
   - No route with that name → notify `Rails: route not found: <name>`.
5. **Fallback** — no resolver recognized the context → `normal! gf` (inside `pcall`;
   on error, echo Neovim's own message as an error, without a Lua stack trace).

### Visual mode
- The selected text (first line of the selection, trimmed, without surrounding quotes or
  a leading `:`) is the input.
- Resolvers tried in order, each only when its file exists:
  partial (same rules as above, using the current file for a name without `/`),
  fixture file (`<text>.yml`), model of table `<text>`, then route `<text>` when it ends
  in `_path` / `_url`.
- Nothing found → default `gf` on the selection (`normal! gv` + `gf`).

### Routes module change
`core/routes.lua` can only show a picker after loading. This task adds one option to
`load_routes()` / `on_command_finished()`: when `opts.on_loaded` is set, call it with the
parsed routes instead of opening the picker. A new public `routes.with_routes(callback)`
uses the cache, or loads with `on_loaded`. Existing `show()` / `refresh()` behaviour does
not change.

### Public API
```lua
---Register the buffer-local gf mappings. No-op unless modules.gf = true.
M.setup()

---Pure resolver used by the mappings and tests.
---@param ctx {root: string, file: string, line: string, col: integer}
---@return GfTarget|nil  nil = not recognized (fall back to default gf)
M.resolve(ctx)

---@param ctx {root: string, file: string, text: string}
---@return GfTarget|nil
M.resolve_text(ctx)
```
`GfTarget` is one of:
- `{ kind = "file", paths = string[], lnum? = integer, notice? = string }` — open (one path)
  or pick (several); `notice` is shown after opening
- `{ kind = "route", name = string }` — look up the route, then `goto_action`
- `{ kind = "missing", message = string }` — recognized but nothing to open

---

## Acceptance Criteria
- [x] Context detection by regex on the current line (no Treesitter)
- [x] Partial: `render "shared/header"` → `app/views/shared/_header.html.erb`; name without
      `/` resolves from the current view folder or controller
- [x] Fixture: `fixtures :users` and `users(:alice)` in test/spec files →
      `test/fixtures/users.yml` (or `spec/fixtures/`), jumping to `alice:`
- [x] Table → model in migrations: `create_table :course_progresses`, `change_table`,
      `add_column :users, ...` → `app/models/course_progress.rb` / `user.rb`;
      `t.references :enrollment` → `app/models/enrollment.rb`; annotate `# Table name:` wins
- [x] Route: `edit_user_path` / `users_url` → `controller#action` of the named route
- [x] Visual selection runs the same resolvers on the selected text
- [x] View engine follows `view.engine` / `view.priority` (erb, haml, slim)
- [x] Format follows the current file (html, json, xml), default html
- [x] Recognized but missing → notify, no fallback; not recognized → Neovim's own `gf`
- [x] Only active when `modules.gf = true`

---

## Implementation Checklist
- [x] Create `lua/rails-tools/core/gf.lua` with `setup()`, `resolve()`, `resolve_text()`
- [x] Partial resolver (name, folder, format, engine order, select when several)
- [x] Fixture resolver (`fixtures :x`, `x(:key)`, test/ and spec/ fixture folders, key line)
- [x] Table → model resolver (method/argument table above, annotate table name first)
- [x] Route helper resolver + `routes.with_routes(callback)` (`opts.on_loaded` in `core/routes.lua`)
- [x] Visual-mode mapping and `resolve_text()`
- [x] Default `gf` fallback without a Lua stack trace
- [x] Buffer-local mappings for ruby/eruby/haml/slim, gated by `modules.gf`; call from `init.lua`
- [x] Sample files in `test-app/` for manual testing (views with partials, fixtures, a migration)
- [x] Create `tests/core/gf_spec.lua` (each resolver, not-recognized cases, gating)
- [x] Add a test for `routes.with_routes()` in `tests/core/routes_spec.lua`
- [x] Update README (Implemented list, Configuration, Usage) and `specs/story.md`

---

## Key Decisions
- **Buffer-local `gf` override, no `:Rails gf`.** Same pattern as the `K` / `gd` override in
  `integrations/lsp.lua`; the user keeps pressing `gf`.
- **Regex only, no Treesitter.** Nothing in the plugin uses Treesitter, the Ruby parser may
  not be installed, minimum Neovim is 0.9, and every supported pattern sits on one line.
- **Missing partial / fixture / model → notify, no create prompt.** Creating files from `gf`
  belongs to `030-gf-constant-stub-generator.md` (#34).
- **Removed "`User` → latest `*_create_users.rb`".** The cursor on a constant should open the
  constant's file (that is #34's job); migration-of-a-model is a related file in
  `020-controller-view-navigation.md`.
- **Fixtures only in test/spec files and only in `fixtures :x` / `x(:key)`.** A bare `:users`
  is too ambiguous (`has_many :users`).
- **Table → model prefers the annotate `# Table name:` line**, so a model with a custom
  `self.table_name` is found; otherwise `singularize` + file name.
- **Route helpers use the routes cache and load it async when empty**, like `:Rails routes`.
- **Visual mode** exists for strings with interpolation (`"shared/#{kind}"`): select
  `shared/header` and press `gf`.

---

## Notes
- Known limits (regex on one line): a `render` call split over several lines with the name
  on another line is not recognized; a fixture file in a sub-folder
  (`test/fixtures/admin/users.yml`, accessor `admin_users`) is not found.
- `030-gf-constant-stub-generator.md` (#34) adds a constant resolver to this module later.
- The default-`gf` fallback runs `normal! gf`, so a filetype plugin's own buffer-local `gf`
  (Neovim's Ruby ftplugin maps `gf` to resolve `require` paths) is replaced in buffers where
  this module attaches.
- Installation example uses `ft = { "ruby", "eruby" }`; haml/slim buffers only get the mapping
  once the plugin is loaded.

---

## Decision Log
- 2026-11-17: Design settled in discussion (9 questions, all accepted as recommended) — see Design and Key Decisions above
- 2026-11-17: Table → model reads annotate blocks per file instead of `annotate.scan` (namespace collision) — see Design above
