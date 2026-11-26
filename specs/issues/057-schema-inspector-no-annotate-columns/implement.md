# Implement plan — BF-057 Schema Inspector shows no columns for models without an annotate block

## Decisions made without you
- Table name order: `self.table_name = "..."` in the model file > annotate `# Table name:` > inferred from the model file path.
  - Reason: `self.table_name` is what Rails actually uses; annotate is generated from the real table, so the two only differ when annotate is stale.
- Inferred name is checked against `db/schema.rb`: try the namespaced name first (`admin/user` -> `admin_users`), then the last segment only (`users`). The first one that exists in `db/schema.rb` wins; if none exists, `table_name` is nil and columns are empty (same as today).
  - Reason: Rails gives `Admin::User` the table `admin_users` only when the `Admin` module defines `table_name_prefix` (the `rails g model admin/user` default), otherwise `users`. Reading that Ruby config is out of scope; checking which table exists covers both cases.
  - Accepted limit: if the app has both `admin_users` and `users` tables and `Admin::User` has no prefix, it picks `admin_users`. Fix by adding `self.table_name` or an annotate block.
- Inference uses the model file path (relative to `app/models/`), not the camelized model name, so no new `underscore` helper is needed. `pluralize` already handles `/` and irregular words on the last segment (checked headless: `admin/person` -> `admin/people`, `admin/user` -> `admin/users`).
- An annotated model whose `# Table name:` is not in `db/schema.rb` keeps today's behaviour (no fallback to inference). An annotate block without a `# Table name:` line falls through to inference.
- `self.table_name` is read only in the literal string form `self.table_name = "x"` / `'x'`. Symbols, string interpolation, constants and `table_name_prefix`/`suffix` are not evaluated.
- `self.table_name` is parsed in `annotate.scan` (it already reads every model file) and stored as a new field `declared_table_name`; no second file read.
- Regression tests follow the existing `schema_spec.lua` pattern: model and schema files are written into a temp Rails root, not added under `tests/fixtures/`.
- Out of scope, not changed: `related_files.table_of_model` (`core/related_files.lua:243-247`, used by "go to schema") and `rails_paths.model_file_for_table` (`core/rails_paths.lua:176-184`) keep their own annotate-or-pluralize logic. STI subclasses (`class Admin < User`) are not mapped to the parent table.

Source: `specs/issues/057-schema-inspector-no-annotate-columns/issue.md` (GitHub #57). Dependencies #56 and #61 are merged on `main`.

## Description
Checked against `main` (82bb64e):
- Confirmed: table lookup uses only the annotate name: `local schema_table = ann.table_name and schema_tables[ann.table_name]` at `core/schema.lua:123` (the issue says 128-135; the code moved, behaviour is the same). With no annotate block `ann.table_name` is nil, so `merge_columns` gets no schema table and `ann.columns` is empty: the model has zero columns.
- Confirmed: `annotate.scan` (`core/annotate.lua:53-70`, issue says 56-66) stores every `app/models/**/*.rb` file except concerns, annotated or not, and `build` adds each to `known_models` (`schema.lua:122`). So the model is known but has no columns.
- Confirmed effect: hover and `gd` (`integrations/lsp.lua:13-26`) and completion (`integrations/cmp.lua:63-78`) read `resolved.models[model].columns`, so all three show nothing for such a model.
- Confirmed: when the column comes only from `db/schema.rb`, `merge_columns` already sets `location = { file = <root>/db/schema.rb, lnum = <column line>, col = 0 }` (`schema.lua:91-92`). So `gd` jumps to the schema line once the table is found; no change needed there.
- Confirmed: `pluralize` handles irregular words and namespaced paths (#61 merged, `core/model_context.lua:66-80`).

## Design
- `core/model_context.lua`: new public `M.table_name_candidates(path)`.
  - `relative = path:match(MODEL_PATH_PATTERN)`; return `{}` when nil.
  - `plural = M.pluralize(relative)`; candidates: `plural:gsub("/", "_")` and the part of `plural` after the last `/`. Drop the second when equal to the first (top-level model).
  - Returns e.g. `app/models/admin/user.rb` -> `{ "admin_users", "users" }`, `app/models/person.rb` -> `{ "people" }`.
- `core/annotate.lua`:
  - New constant `DECLARED_TABLE_NAME_PATTERN = "^%s*self%.table_name%s*=%s*[\"']([%w_]+)[\"']"`.
  - New public `M.declared_table_name(lines)`: first line matching the pattern, else nil.
  - `M.scan`: `block.declared_table_name = M.declared_table_name(lines)`. Add `---@field declared_table_name string|nil` to `AnnotatedModel`.
- `core/schema.lua`:
  - New local `resolve_table_name(ann, schema_tables)`: return `ann.declared_table_name` if set, else `ann.table_name` if set, else the first of `model_context.table_name_candidates(ann.file)` present in `schema_tables`, else nil.
  - `build`: `local table_name = resolve_table_name(ann, schema_tables)`; `schema_table = table_name and schema_tables[table_name]`; `table_name = table_name` in the model entry.
  - `merge_columns` unchanged.
  - Stale annotate rule: ignore the annotate columns only when the resolved table exists in `schema_tables` and differs from `ann.table_name`; if the resolved table is missing from `schema.rb`, keep the annotate columns.
- No change to `lsp.lua`, `cmp.lua`, `infer_model`, `model_for_path`, cache or `setup`.

## Acceptance Criteria
- [ ] Un-annotated `app/models/user.rb` with `users` in `db/schema.rb`: `resolve().models.User.columns` has every `t.*` column of `users`, `table_name == "users"`, and `email.location` is `{ file = <root>/db/schema.rb, lnum = <email line>, col = 0 }`.
- [ ] Un-annotated `app/models/person.rb` resolves to table `people`.
- [ ] Un-annotated `app/models/admin/user.rb` resolves to `admin_users` when that table exists, else to `users`.
- [ ] `self.table_name = "orders"` in an un-annotated model resolves to `orders`; it also wins over an annotate `# Table name:` that names another table.
- [ ] No matching table: `table_name` is nil and `columns` is empty (no error).
- [ ] Annotated models behave as before: all existing `schema_spec.lua` tests pass unchanged.
- [ ] `make test` and `make lint` pass.

## Implementation Checklist
1. `lua/rails-tools/core/model_context.lua`: add `M.table_name_candidates(path)` after `M.model_for_path`, with LuaDoc (`---@param path string`, `---@return string[]`). Reuse `MODEL_PATH_PATTERN`; no new pattern.
2. `tests/core/model_context_spec.lua`: new `describe("model_context.table_name_candidates")`:
   - `/r/app/models/user.rb` -> `{ "users" }`.
   - `/r/app/models/person.rb` -> `{ "people" }`.
   - `/r/app/models/admin/user.rb` -> `{ "admin_users", "users" }`.
   - `/r/app/models/admin/billing/invoice_item.rb` -> `{ "admin_billing_invoice_items", "invoice_items" }`.
   - `/r/lib/foo.rb` -> `{}`.
3. `lua/rails-tools/core/annotate.lua`: add `DECLARED_TABLE_NAME_PATTERN` constant after `local M = {}`, add `M.declared_table_name(lines)` with LuaDoc, set `block.declared_table_name` in `M.scan`, add the `---@field` line to `AnnotatedModel`.
4. `tests/core/annotate_spec.lua`:
   - `describe("annotate.declared_table_name")`: double quotes, single quotes, indented inside the class -> name; no such line -> nil; `self.table_name = :orders` -> nil.
   - In `describe("annotate.scan")`: a model with `self.table_name = "legacy_users"` has `declared_table_name == "legacy_users"`.
5. `lua/rails-tools/core/schema.lua`: `require("rails-tools.core.model_context")`, add local `resolve_table_name(ann, schema_tables)` above `build`, use it in `build` as in Design.
6. `tests/core/schema_spec.lua`, `describe("schema.resolve")`, add (temp-root files, same `write` helper):
   - Regression: un-annotated `app/models/user.rb` (`class User < ApplicationRecord` / `end`) + `SAMPLE_SCHEMA` -> `table_name == "users"`, `email.signature == ":string null: false"`, `email.location == { file = tmp_dir .. "/db/schema.rb", lnum = 3, col = 0 }`.
   - Irregular: schema with `create_table "people"` + un-annotated `app/models/person.rb` -> `table_name == "people"` and its column present.
   - Namespaced: schema with `admin_users` and `users`, un-annotated `app/models/admin/user.rb` -> `admin_users`; second case with only `users` -> `users`.
   - Explicit: un-annotated `app/models/purchase.rb` with `self.table_name = "orders"` -> `orders`, has `user_id`.
   - Explicit beats annotate: `app/models/user.rb` with `# Table name: users` and `self.table_name = "orders"` -> `orders`. Also add an annotate column (e.g. `email`) not in `orders`; assert it is absent from the columns and the `orders` columns are present (risk review: annotate columns must not mix into the explicit table).
   - No table: un-annotated `app/models/widget.rb` + `SAMPLE_SCHEMA` -> `table_name` nil, `columns` empty.
7. Check the diff against `~/.claude/code-rules/` (Lua: constants at top, LuaDoc on public functions, no comments, 2-space indent as in these files).
8. `make test` -> all pass. `make lint` -> no warnings.

## Notes
- Existing test "invalidates the resolved cache when a saved model file drops its annotate block" (`schema_spec.lua`) writes no `db/schema.rb`, so inference finds no table and `email` stays nil after the save. It still passes without change.
- The `ResolvedModel.table_name` field now also holds inferred names; no caller outside `schema.lua` reads it (grep `table_name` in `lua/`: only `rails_paths.lua:179` and `related_files.lua:245`, both read `annotate.parse` directly).
- LuaDoc `known_models` comment at `schema.lua:73` ("annotated or not") stays accurate.
- Follow-up candidate (not this issue): share `resolve_table_name` with `related_files.table_of_model` so "go to schema" also honours `self.table_name` and namespaces.

Review: Approved
