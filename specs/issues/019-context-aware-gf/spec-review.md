---
GitHub Issue: (to be filled after sync)
Status: RESOLVED (spec revised, Review: Approved)
---

## Summary
- The spec is detailed, its code references are almost all correct, and the 019a / 019b split is sound.
- Two design points are wrong or not implementable as written: the controller `render "x"` rule, and the fixture accessor needing a token type the token helper does not produce.
- Q4's and Q2's reasoning each rest on a partly wrong reading of another file; the recommendations still mostly hold (Q4 overridden below).
- Code read from `origin/main` 1717f4e. Risk report: `~/.ai-metrics/orchestrator/20261114-1728-019-context-aware-gf-risk.md`.

## Well-Defined
- Scope split into 019a / 019b with reasons (Q1), and the out-of-scope list (Notes).
- Mapping design: augroup, file patterns instead of `FileType`, Rails-root check, already-loaded buffers, public `M.open()`.
- Three-way finder result (target / recognised-but-missing / nil) and the fallback order.
- Table → model lookup order with traced examples; the traces match the code.
- Known limits are listed explicitly.
- Every open question has a recommendation with risk both ways.
- Test list in the checklist maps to each finder.

## Factual claims checked against the code
Correct (each checked on `origin/main` 1717f4e or by running nvim):
- `modules.gf = false` at `lua/rails-tools/config.lua:47`.
- `view` defaults at `config.lua:121-124`; no code reads them (grep of `lua/` for `view.` and `.view` returns nothing).
- `lua/rails-tools/utils.lua` returns `{}`.
- No Treesitter use in `lua/`.
- `/usr/local/lib/nvim/parser/` holds only `c, diff, lua, markdown, markdown_inline, query, vim, vimdoc` on NVIM v0.13.0-dev-1504.
- Note: on this machine a Ruby parser loads anyway, from `~/.local/share/nvim/site/parser/ruby.so` (user-installed); this matches the spec's "only when the user installs one".
- `vim.filetype.match` on `a.html.slim` returns nil; `.html.erb` → `eruby`, `.html.haml` → `haml`.
- Also true but not stated: `*.jbuilder` has no core filetype either (returns nil), which is one more reason for file patterns.
- `singularize`: `courses` → `cours`, `cases` → `cas`, `people` → `people`, `course_progresses` → `course_progress` (`core/model_context.lua:13-22`).
- `annotate.scan` at `core/annotate.lua:53-68`, keyed by base name at line 60.
- `schema.resolve()` model entries have no `file` field (`core/schema.lua:121-128`).
- `routes_cache` private (`core/routes.lua:33`), `def_line` at `routes.lua:104-112`, `pcall(vim.cmd.edit, ...)` at `routes.lua:129`.
- `rails.root` at `detectors/rails.lua:55`; module setups at `init.lua:21-24`, `keymaps.setup()` at `init.lua:19`.
- Temp root at `tests/core/schema_spec.lua:106-108`; `tests/init_spec.lua` has the `package.loaded` reset.
- `README.md:35` and `README.md:133-134`; `specs/story.md` lines 316-332, 322-325, 339, 348, 547, 644.

Wrong or overstated:
- Line 89-93 "Path rules (Rails convention)": `render "header"` in a controller renders the template `app/views/<controller>/header.*`, not the partial `_header` (Rails Guides "Layouts and Rendering in Rails" §2.2.2-2.2.3; not fetched in this session, high confidence). Only `render partial: "header"` is a partial there. Repo example of controller render meaning a template: `test-app/app/controllers/users_controller.rb:28` `render :new`.
- Resolution of the three items below: the controller claim and Q4 / Q2 rationale are corrected in the spec.
- Q4 risk-if-no: `README.md:133-134` describes `keymaps.enabled` as switching off the `<leader>r` prefix keymaps. The plugin's existing buffer-local overrides of native keys (`K` / `gd`, `integrations/lsp.lua:63-90`, set up at `lsp.lua:97-116`) are not gated by it. So mapping `gf` with `keymaps.enabled = false` does not contradict the README as claimed.
- Q2 risk-if-kept: "030 (#34) makes `gf` on a constant open its class file". 030 says a bare constant (no `::`, e.g. `User`) falls back to default `gf` (030 Acceptance Criteria, "For a bare constant (no `::`) ... falls back to default gf"). So for the migration finder's own example `User` there is no clash; 030 itself is inconsistent on bare constants (its first AC says bare constants resolve). The other reason (story gives no file or position) still holds, so Q2's answer stands.

## Issues Found

### 1. Controller `render "x"` treated as a partial (blocking)
> in a controller (`app/controllers/admin/users_controller.rb`) → `app/views/admin/users/_header`

**Problem:** Wrong Rails convention (see wrong claims). AC "`render "header"` in `app/controllers/admin/users_controller.rb` opens `app/views/admin/users/_header.*`" would ship a wrong behaviour: `gf` on `render "edit"` reports "partial not found" or opens an unrelated partial.
**Suggest:** In controllers, recognise only `render partial: "x"` / `:partial => "x"` as partials. Either drop bare `render "x"` in controllers (default `gf`), or resolve it as the template `app/views/<ctrl>/x.*` and say so. Fix the AC and the test list.
**Resolution:** Fixed (user-approved). Controllers recognise only `partial:` / `:partial =>`, bare `render "x"` falls back to default `gf`. AC, Design and tests updated, Rails Guides claim labelled as not fetched.

### 2. Fixture accessor needs a token the token helper does not produce (blocking)
> An accessor call `users(:one)` with the cursor on `users` or on `:one`

**Problem:** "Token under the cursor" only finds quoted strings and symbols. `users` is a bare identifier, so "cursor on `users`" cannot be implemented as specified, and the token helper tests (checklist) do not cover it.
**Suggest:** Either add identifiers followed by `(` to the token helper, or limit the accessor form to the cursor on `:one`. Update the AC to say where the cursor is.
**Resolution:** Fixed (user-approved). Only the cursor on `:one` is supported, token helper unchanged, AC states the cursor position, cursor on `users` tested as nil.

### 3. No `application/` fallback and no layout rule for view-relative partials
> in a view (`app/views/<dir>/<file>`) → `app/views/<dir>/_header`

**Problem:** Rails looks up a bare partial name by the controller's prefixes, then `application/` (template inheritance; same Rails Guides chapter, not fetched, high confidence). A shared partial in `app/views/application/_header.*`, or `render "header"` inside `app/views/layouts/*.erb`, gets "partial not found" though the file exists.
**Suggest:** After `<dir>/_name`, also try `app/views/application/_name`. Add the layout case to Known limits.
**Resolution:** Fixed (auto). `app/views/application/_name` tried second, layout case added to Known limits, AC and test added.

### 4. Partial ranking rules are ambiguous
> 1. Format equals the current format, or the candidate has no format part
> 2. Engine order: `view.engine` when it is not `"auto"`, else ...

**Problem:** Not clear whether rule 1 filters or only ranks: if it filters, a json view rendering `_x.html.erb` reports "not found" though the file exists. Not clear what happens with `view.engine = "slim"` when no slim candidate exists (fall back to the auto order, or nothing).
**Suggest:** State "rank, never filter" and "a fixed `view.engine` goes first, then the auto order". Add one test for each.
**Resolution:** Fixed (auto). "Rank, never filter" and "fixed `view.engine` first, then auto order" stated, one AC and one test each.

### 5. `M.open()` outside a Rails buffer is undefined
> Public `M.open()` is what the mapping calls, so users can map it to another key.

**Problem:** A user mapping is usually global, so `M.open()` can run where `rails.root()` is nil (`detectors/rails.lua:55-58`). The spec does not say whether it falls back to default `gf` or what the finders get as `root`.
**Suggest:** One line: no Rails root → fallback `gf`. Add one test.
**Resolution:** Fixed (auto). No Rails root → default `gf`, AC and test added.

### 6. Fallback via `nvim_feedkeys` appends to typeahead
> `vim.api.nvim_feedkeys("gf", "n", false)`

**Problem:** Without the `i` flag the keys go to the end of the typeahead (`:h nvim_feedkeys`, not probed), so in a macro or `:normal gfdd` the `dd` may run before `gf`. Guess, medium confidence.
**Suggest:** Use mode `"ni"`, or `pcall(vim.cmd.normal, { "gf", bang = true })` and notify the error. Probe once headless before deciding.
**Resolution:** Fixed (auto). Mode `"ni"` chosen, confirmed by headless probe on v0.13.0-dev (`"n"` ran `dd` first, `"ni"` ran `gf` first).

### 7. Fixture `fixtures` line rule: indentation not stated
> A symbol on a line that starts with `fixtures`

**Problem:** In Minitest, `fixtures :users` is indented inside the class. "Starts with" could be read literally.
**Suggest:** "first word after leading whitespace", like the migration rule.
**Resolution:** Fixed (auto). Rule is now "first word after leading whitespace", indented test added.

### 8. Known limits missing irregular plurals
> 2. `app/models/<model_context.singularize(table)>.rb`

**Problem:** `people` → `people.rb`, not `person.rb` (verified singularize output); same for `mice`, `children`. Without an annotate block these show "no model found".
**Suggest:** Add a line to Known limits.
**Resolution:** Fixed (auto). Irregular plurals line added to Known limits.

### 9. 030 depends on Treesitter that 019a drops
> 030 checklist: "Treesitter node type for Ruby constants, regex fallback per `019-context-aware-gf.md`'s existing approach"

**Problem:** After Q3, 019a has no Treesitter, so 030's first checklist item points at nothing. The spec says 019a must land first but does not list 030 as needing an update.
**Suggest:** Add a checklist line "update 030 spec: regex only, Treesitter in 019b".
**Resolution:** Fixed (auto). Checklist line added to update the 030 spec (regex only, Treesitter in 019b).

### 10. Overlap with 020 `from_migration()` not mentioned
> 020 story items: "Implement `from_migration()` - Migration → model of the table it creates/changes" (`specs/story.md`, L4-020)

**Problem:** 020 will need the same table → model lookup. Two copies could resolve the same migration to different models.
**Suggest:** One Notes line: 020 reuses the 019a table → model lookup (like the existing note on view ranking).
**Resolution:** Fixed (auto). Notes line: 020 reuses the 019a table → model lookup.

### 11. Migration method list misses join tables (minor)
**Problem:** `create_join_table :users, :courses` / `drop_join_table` take table names but are not listed (Q7 aims for "all table-first methods").
**Suggest:** Add them (both arguments), or say they are out of scope.

## Open questions — verdicts
- Q1 (split): sound. Resolution: accepted (auto).
- Q2 (drop migration finder): sound answer, but fix the rationale (see wrong claims). Resolution: decided, the 030 clash reason removed from the spec. Risk of dropping: one story item gone. Risk of keeping: no defined file/position for it.
- Q3 (regex only): sound. Add the 030 follow-up (Issue 9). Resolution: accepted (auto).
- Q4 (gate on `modules.gf` and `keymaps.enabled`): override, see below. Resolution: override applied (user-approved).
- Q5 (no create prompt): sound. Resolution: accepted (auto).
- Q6 (jump to `one:`): sound. Resolution: accepted (auto).
- Q7 (all table-first methods): sound; add join tables (Issue 11). Resolution: accepted (auto).
- Q8 (`annotate.scan` per `gf`): sound; the cost is correctly labelled an unmeasured assumption. Resolution: accepted (auto).
- Q9 (create GitHub issue after approval): sound; the `md-to-github-issues` skill exists in the user's skills folder. Resolution: accepted (auto).
- No question lacks a recommendation.
**Resolution:** Fixed (auto). `create_join_table` / `drop_join_table` added as first-or-second-argument methods, AC and test updated.

### Q4 override
- Better answer: map `gf` whenever `modules.gf = true`, regardless of `keymaps.enabled`; keep `M.open()` public.
- Reason: `modules.gf` is already an explicit opt-in (default false, `config.lua:47`); `keymaps.enabled` covers the `<leader>r` prefix keys (`README.md:133-134`, `keymaps.lua:65-72`); the existing `K` / `gd` overrides ignore it (`lsp.lua:97-116`).
- Risk of doing it: a user who disabled all plugin keymaps and enabled `gf` gets `gf` remapped (which is what `modules.gf` asks for).
- Risk of not doing it: `modules.gf = true` + `keymaps.enabled = false` silently does nothing, and the user must find `M.open()` in the docs.
- If the original answer is kept: document the double gate in README next to the `modules` example.

## Score (6/10)
- AC: ❌ (controller rule wrong; accessor cursor position undefined; ranking AC not precise enough to test the edge cases)
- Checklist: ✅ (specific and complete for the design as written; needs lines for Issues 1-3, 5, 9)
- Design: ✅ (no wireframe needed; `specs/rules/` not applicable)

## Status
- [x] READY — all issues resolved on 2026-11-14, decisions recorded in the spec's Decisions section
- [ ] PENDING


## Risk report items
- `render "x"` in controller → resolved with Issue 1.
- `application/` partials → resolved with Issue 3.
- Accessor token → resolved with Issue 2.
- `M.open()` outside Rails → resolved with Issue 5.
- `nvim_feedkeys` order → resolved with Issue 6.
- Other plugin's `gf` → out of scope, listed in the spec Notes under "Risks to test".
- `view.priority` merge on 0.9 → out of scope, listed under "Risks to test".
- Negative Rails-root cache → pre-existing, listed under "Risks to test".
