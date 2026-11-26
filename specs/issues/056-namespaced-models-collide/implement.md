# Implement plan — BF-056 Namespaced models and `&.` receivers

Review: Approved

## Decisions made without you
- Concerns (`app/models/concerns/**`) are not models: `model_for_path` returns nil for them and `annotate.scan` skips them.
  - Reason: Rails loads `app/models/concerns/` as its own root (constant `Searchable`, not `Concerns::Searchable`), and a concern is a module with no table, so it never has columns to show.
  - Risk of the alternative (keep them, keyed by the bare name): a concern shares the key space with real models, so a concern and a model with the same name would overwrite each other again, the same bug this task fixes.
- Namespace keys use Ruby constant form `Admin::User` (one camelized segment per directory, joined by `::`).
- `annotate.scan` derives its key through `model_for_path`, so the scan key and the open buffer's model always come from one function.
- `infer_model` is not changed: a receiver (`user`, `admin_user`) still only maps to top-level model names. No fallback to `Admin::User` when no top-level `User` exists (needs new matching logic, ambiguous when namespaces share a basename). File a follow-up issue if users hit it.
- Existing comments and LuaDoc are not edited (standing rule); the lines that become inaccurate are listed in Notes and flagged in the final report.
- Known limit accepted: apps that collapse an `app/models` subfolder (Zeitwerk collapse, extra autoload paths) now get a namespaced key, so `x.col` outside that model file stops resolving. Supporting Zeitwerk config is out of scope.

Source: `specs/issues/056-namespaced-models-collide/issue.md` (GitHub #56), `specs/story.md:381-386` (BF-056).

## Description
- `model_for_path` keeps only the file's last segment: pattern `app/models/.-([%w_]+)%.rb$` (`core/model_context.lua:68`). `app/models/admin/user.rb` returns `User`.
- `annotate.scan` keys by basename: `camelize(fnamemodify(file, ":t:r"))` (`core/annotate.lua:60`), then `by_model[model_name] = block` (`annotate.lua:63`). Two files with the same basename overwrite each other.
- Reproduced headless on `test-app/` (has `app/models/user.rb` and `app/models/admin/user.rb`): `annotate.scan` returns only one key, `User`, pointing to `user.rb`. `Admin::User` (table `admin_users`) is lost.
- `annotate.scan` globs `app/models/**/*.rb` (`annotate.lua:55`), so concerns are scanned too. Reproduced headless: `model_for_path("app/models/concerns/searchable.rb")` returns `Searchable`.
- The scan result feeds `schema.resolve` (`core/schema.lua:115-128`): both `models` and `known_models` are keyed by the scan key. Callers of `resolve`: `integrations/lsp.lua:13` (hover `K`, `gd`) and `integrations/cmp.lua:63` (completion).
- `model_for_path` callers: `integrations/lsp.lua:58` and `integrations/cmp.lua:69`, both for the current buffer's model. No other caller in `lua/` (grep).
- `&.` receiver: `word_and_receiver` checks the char before the word is `.` (`integrations/context.lua:35`), then matches the receiver with `@?([%a_][%w_]*)$` on the text before the dot (`context.lua:39-40`). For `user&.email` that text is `user&`, so the match fails. Reproduced headless: `word_and_receiver("user&.email", 7)` returns `nil, "email"`.
  - Effect: `lsp.lua:17` then uses `current_model`, so inside a model file hover/`gd` show the open model's column, outside a model file nothing.
- cmp receiver pattern `@?([%a_][%w_]*)%.[%w_]*$` (`integrations/cmp.lua:22`) returns nil for `user&.` (reproduced headless), so `complete` returns no items (`cmp.lua:58-60`).
- `gf` also calls `word_and_receiver` but ignores the receiver (`core/gf.lua:300`), so the `&.` fix does not change `gf`.

## Design
- `core/model_context.lua`, `model_for_path` only:
  - Take the path after the last `app/models/`: `path:match(".*app/models/(.+)%.rb$")`. Greedy prefix so a root path that itself contains `app/models/` does not leak into the name.
  - Return nil when there is no match or the relative path starts with `concerns/`.
  - Split on `/`. Each segment must match `^[%w_]+$`, else return nil. Camelize each segment and join with `::`.
  - Patterns as local constants at the top of the file (Lua rule: named patterns are constants).
- `core/annotate.lua` `scan`: `local model_name = model_context.model_for_path(file)`; only store the block when `model_name` is not nil.
- `integrations/context.lua:40`: receiver pattern becomes `@?([%a_][%w_]*)&?$` (optional `&` before the dot).
- `integrations/cmp.lua:22`: pattern becomes `@?([%a_][%w_]*)&?%.[%w_]*$`.
- No change to `infer_model`, `singularize`, `pluralize`, `camelize`, `schema.lua`, `lsp.lua`.
- `schema.setup` invalidation pattern `app/models/.+%.rb$` (`schema.lua:163`) still matches concerns. Kept: an extra cache flush on concern save is harmless.

## Acceptance Criteria
- [ ] `model_for_path("app/models/admin/user.rb")` returns `Admin::User`; `app/models/user.rb` still returns `User`.
- [ ] `annotate.scan` keys models by full namespaced name; `User` and `Admin::User` both appear, each with its own file and table name.
- [ ] `app/models/concerns/**`: `model_for_path` returns nil and `annotate.scan` has no entry for it (documented in Decisions above).
- [ ] `word_and_receiver("user&.email", col on email)` returns `"user", "email"`, so `K`/`gd` resolve via receiver `user`.
- [ ] cmp `complete("user&.")` returns the `User` columns.
- [ ] Regression tests below added; `make test` and `make lint` pass.

## Implementation Checklist
1. `lua/rails-tools/core/model_context.lua`: after `local M = {}`, add
   ```lua
   local MODEL_PATH_PATTERN = ".*app/models/(.+)%.rb$"
   local CONCERNS_PREFIX = "concerns/"
   local MODEL_SEGMENT_PATTERN = "^[%w_]+$"
   ```
2. Same file, replace the body of `M.model_for_path` (lines 68-72):
   ```lua
   local relative = path:match(MODEL_PATH_PATTERN)
   if not relative or vim.startswith(relative, CONCERNS_PREFIX) then
     return nil
   end
   local segments = vim.split(relative, "/", { plain = true })
   for index, segment in ipairs(segments) do
     if not segment:match(MODEL_SEGMENT_PATTERN) then
       return nil
     end
     segments[index] = M.camelize(segment)
   end
   return table.concat(segments, "::")
   ```
   Do not touch `singularize` / `pluralize` / `infer_model` / `camelize`.
3. `lua/rails-tools/core/annotate.lua` `M.scan`: replace line 60 with `local model_name = model_context.model_for_path(file)` and wrap lines 61-63 in `if model_name then ... end`.
4. `lua/rails-tools/integrations/context.lua:40`: pattern `"@?([%a_][%w_]*)&?$"`.
5. `lua/rails-tools/integrations/cmp.lua:22`: pattern `"@?([%a_][%w_]*)&?%.[%w_]*$"`.
6. `tests/core/model_context_spec.lua`, `describe("model_context.model_for_path")`, add:
   - `app/models/admin/user.rb` -> `"Admin::User"`.
   - `/rails/app/models/admin/billing/invoice_item.rb` -> `"Admin::Billing::InvoiceItem"`.
   - `app/models/concerns/searchable.rb` -> nil.
   - `/work/app/models/demo/app/models/user.rb` -> `"User"` (last `app/models/` wins).
   - `app/models/foo-bar.rb` -> nil.
7. `tests/core/annotate_spec.lua`, `describe("annotate.scan")`, add (use `vim.fn.mkdir(..., "p")` for subdirs):
   - `it("keys namespaced models by full name, so same basenames do not collide")`: write `user.rb` (Table name: users) and `admin/user.rb` (Table name: admin_users); assert `by_model.User.table_name == "users"`, `by_model["Admin::User"].table_name == "admin_users"`, and each `.file` is its own path.
   - `it("skips app/models/concerns")`: write `concerns/searchable.rb`; assert `by_model.Searchable` and `by_model["Concerns::Searchable"]` are nil.
8. `tests/core/schema_spec.lua`: new `it("keeps namespaced models apart in models and known_models")` using the existing `write` helper: `app/models/user.rb` and `app/models/admin/user.rb` with different tables; assert `resolved.known_models["Admin::User"]` is true and `resolved.models["Admin::User"].table_name == "admin_users"`.
9. `tests/integrations/context_spec.lua`: add `it("treats user&.email like user.email")`: `word_and_receiver("user&.email", 7)` returns `"user", "email"`; also `"@user&.email"` returns `"user", "email"`.
10. `tests/integrations/cmp_spec.lua`: add `it("suggests columns after a safe navigation receiver")`: same setup as the first test, `complete("user&.")` returns 1 item `email`.
11. `tests/integrations/lsp_spec.lua`: add a NEW `describe("namespaced model file")` (own describe, so the existing `user.email` `before_each` that writes `user.rb` does not run): write only `admin/user.rb` (mkdir `admin`) with an annotate block for `admin_users` containing column `username`; `lsp.hover_lines(nil, "username", "Admin::User", tmp_dir)` matches `Admin::User`; and `hover_lines("user", "username", nil, tmp_dir)` is nil (documents the current `infer_model` limit).
12. Run `make test` and `make lint`.
13. Tick BF-056 items in `specs/story.md` and the acceptance criteria in `issue.md`.

## Risks to test
- Same-basename overwrite is gone: step 7 test, plus headless `annotate.scan` on `test-app/` must return both `User` and `Admin::User`.
- Project with only `app/models/admin/user.rb` (no top-level `User`): `user.email` resolved to it before, now resolves to nothing. Behaviour change, covered by step 11; see Open questions.
- Inside `app/models/admin/user.rb`, bare `email` and `self.email`: `current_model` is now `Admin::User`, so hover must show its columns. Step 11 first assertion.
- Concern file open in the buffer: `current_model` was `Searchable` (no columns), now nil. Same visible result (nothing shown). Test: `test-app/app/models/` only has an empty `concern/` (singular) folder, so create a temporary `app/models/concerns/searchable.rb` in a copy, open it and press `K` on a word; expect normal LSP hover. Unit coverage: step 6 and step 7.
- Real nvim-cmp popup on `user&.`: the unit test stubs cmp, so real triggering after `&` is chưa xác nhận. Test manually: in `test-app/`, type `user&.` in a ruby buffer with cmp on; expect `User` columns in the menu.
- Root path containing `app/models/`: step 6 last-but-one case.
- Merge conflict with BF-061 (#61, edits `singularize`/`pluralize` and adds constants near the top of `model_context.lua`): whichever merges second rebases and reruns `tests/core/model_context_spec.lua`. Conflict is likely only in the constants block.

## Notes
- Do NOT touch: `singularize`, `pluralize`, `infer_model`, `camelize`, `schema.lua`, `lsp.lua`, `gf.lua`, `rails_paths.lua`, `related_files.lua`. No new comments.
- Existing tests are not changed; all current `model_for_path` / `scan` / cmp / context assertions keep their values.
- LuaDoc that becomes inaccurate (NOT edited, existing comments stay; flag each in the final report): `annotate.lua:50` "Scan every `app/models/**/*.rb` file" (concerns now skipped), `annotate.lua:52` "keyed by camelized model name", `schema.lua:72` "keyed by camelized model name", `schema.lua:73` "every model found under app/models", `model_context.lua:39` "set of camelized model names" (now includes `Admin::User`), `model_context.lua:40` and `:66` "app/models/**/*.rb file" / "model name (camelized)" (now namespaced, nil for concerns).
- Pre-existing, unrelated to this change: the `app/models/` pattern is not anchored to a `/`, so `myapp/models/x.rb` also matches.

## Open questions
none (all answered, see Decisions made without you).
