# Implement plan — BF-061 singularize/pluralize irregular and uncountable words

## Related
- [Original issue](./issue.md)

Source: `specs/issues/061-singularize-pluralize-irregular-words/issue.md` (GitHub #61), `specs/story.md` (BF-061).

## Description
- `singularize` (`model_context.lua:13-22`) and `pluralize` (`model_context.lua:26-33`) only have suffix rules. No irregular words, no uncountable words.
- Current output, run through `nvim --headless` on `main` (0bfe0ce):
  - singularize: `movies → movy`, `people → people`, `children → children`, `men → men`, `mice → mice`, `oxen → oxen`, `news → new`, `series → sery`, `species → specy`, `sales_people → sales_people`.
  - pluralize: `person → persons`, `child → childs`, `man → mans`, `woman → womans`, `mouse → mouses`, `ox → oxes`, `news → newses`, `equipment → equipments`, `admin/person → admin/persons`.
- Reference: ActiveSupport 8.1 (local gem) gives `person/people`, `child/children`, `man/men`, `woman/women`, `mouse/mice`, `ox/oxen`, `movie/movies`, and keeps `news`, `series`, `species`, `equipment`, `information` unchanged both ways.

## Design
- Two lookup tables at the top of `model_context.lua`, checked before the existing suffix rules:
  - `IRREGULARS` (singular → plural): person, child, man, woman, mouse, ox, movie.
  - `UNCOUNTABLES` (set): equipment, information, series, species, news.
  - `SINGULARS_OF_IRREGULARS` (plural → singular), built once from `IRREGULARS`, so each pair is written once.
- `movie` goes in the irregular table, not a new `-ies` rule. Its plural is already right (`movies`); only `singularize("movies")` is wrong. One table keeps both directions in sync.
- Match only the last segment of the word, after the last `/` or `_`. The prefix is kept as is.
  - Needed because callers pass more than a bare word: `pluralize("admin/person")` (model path, `related_files.lua:157`), `singularize("sales_people")` (table name, `rails_paths.lua:183`; receiver, `infer_model`).
  - Whole-segment match is simpler than suffix match and avoids false hits inside compound words written without a separator (e.g. `salesperson` stays on the old rules). `box → boxes` holds either way: ActiveSupport's `ox` rule is anchored to the whole word too.
- Order in each function: uncountable → return the word unchanged; irregular → prefix .. mapped segment; else the existing rules, unchanged.
- Existing suffix rules are not touched (Change scope).

## Behaviour change per caller
Only words whose last segment is in the two tables change. Every other input gives the same result as before.
- `rails_paths.model_file_for_table` (`rails_paths.lua:183`), fallback when no model has a matching annotate `# Table name:`:
  - `people` → `app/models/person.rb` (was `people.rb`); `news` → `news.rb` (was `new.rb`).
  - Reached from: `:Rails related` model lookup in a migration (`related_files.lua:189`), `gf` on a `create_table :people` argument (`gf.lua:251`), `gf` on a bare word that is not a partial or fixture (`gf.lua:333`).
- `related_files.find_model` (`related_files.lua:211`): from a `people` controller/view → `app/models/person.rb` (and `<namespace>/person.rb` first).
- `related_files.find_controller` (`related_files.lua:157`): from `app/models/person.rb` → `people_controller.rb` (was `persons_controller.rb`); namespaced `admin/person` → `admin/people_controller.rb`.
- `related_files.table_of_model` (`related_files.lua:246`), only when the model has no annotate table name:
  - schema lookup (`find_schema`), fixture lookup (`find_fixture`, `related_files.lua:268`) and migration lookup (`find_migrations`, `related_files.lua:294`) use `people` / `children` / `news` instead of `persons` / `childs` / `newses`.
  - Example: an un-annotated `app/models/person.rb` now finds migrations that touch `people` (was `persons`).
- `model_context.infer_model` (`model_context.lua:52`), used by LSP hover/`gd` (`integrations/lsp.lua:17`) and cmp (`integrations/cmp.lua:70`):
  - It tries `camelize(word)` before `camelize(singularize(word))` (`model_context.lua:51-52`).
  - receiver `people` → `Person`, `children` → `Child`, `sales_people` → `SalesPerson` when those models exist.
  - `news` with a `News` model already gives `News` today (camelize runs first); unchanged.
  - Only `news` change: an app with a `New` model and no `News` model used to get `New`; now gets `current_model` (or nil outside a model file).

## Acceptance Criteria
- [ ] `singularize` maps people→person, children→child, men→man, women→woman, mice→mouse, oxen→ox, movies→movie.
- [ ] `pluralize` maps person→people, child→children, man→men, woman→women, mouse→mice, ox→oxen, movie→movies.
- [ ] `singularize` and `pluralize` return equipment, information, series, species, news unchanged.
- [ ] Prefixes are kept: `sales_people → sales_person`, `admin/person → admin/people`, `admin/news` unchanged both ways.
- [ ] Words that only end like a table entry keep the old rules: `fox → foxes`, `foxes → fox`.
- [ ] Existing tests in `tests/core/model_context_spec.lua` pass unchanged (e.g. `categories → category`, `day → days`).
- [ ] `make test` and `make lint` pass.

## Implementation Checklist
1. `lua/rails-tools/core/model_context.lua`: after `local M = {}`, add
   ```lua
   local IRREGULARS = {
     person = "people",
     child = "children",
     man = "men",
     woman = "women",
     mouse = "mice",
     ox = "oxen",
     movie = "movies",
   }

   local UNCOUNTABLES = {
     equipment = true,
     information = true,
     series = true,
     species = true,
     news = true,
   }

   local SINGULARS_OF_IRREGULARS = {}
   for singular, plural in pairs(IRREGULARS) do
     SINGULARS_OF_IRREGULARS[plural] = singular
   end

   ---@param word string
   ---@return string prefix, string last_segment
   local function split_last_segment(word)
     return word:match("^(.-)([^/_]*)$")
   end
   ```
2. Same file, `M.singularize`: insert at the top of the function body, before the `ies$` check
   ```lua
   local prefix, last_segment = split_last_segment(word)
   if UNCOUNTABLES[last_segment] then
     return word
   end
   if SINGULARS_OF_IRREGULARS[last_segment] then
     return prefix .. SINGULARS_OF_IRREGULARS[last_segment]
   end
   ```
   The rest of the function stays as is.
3. Same file, `M.pluralize`: insert at the top of the function body, before the `[^aeiou]y$` check
   ```lua
   local prefix, last_segment = split_last_segment(word)
   if UNCOUNTABLES[last_segment] then
     return word
   end
   if IRREGULARS[last_segment] then
     return prefix .. IRREGULARS[last_segment]
   end
   ```
   The rest of the function stays as is. Keep the existing LuaDoc of both functions.
4. `tests/core/model_context_spec.lua`, new `describe("model_context irregular and uncountable words", ...)` after the `model_context.pluralize` block:
   - Local `irregular_pairs = { { "person", "people" }, { "child", "children" }, { "man", "men" }, { "woman", "women" }, { "mouse", "mice" }, { "ox", "oxen" }, { "movie", "movies" } }`.
   - Loop over it, one `it` per pair and direction: `it("singularizes " .. plural .. " to " .. singular)` and `it("pluralizes " .. singular .. " to " .. plural)`.
   - Local `uncountables = { "equipment", "information", "series", "species", "news" }`; loop, one `it` per word asserting `singularize(word) == word` and `pluralize(word) == word`.
   - `it("keeps the prefix before the last / or _ segment")`: `sales_people → sales_person`, `sales_person → sales_people`, `admin/person → admin/people`, `admin/people → admin/person`, `admin/news` unchanged both ways.
   - `it("matches whole segments only")`: `pluralize("fox") == "foxes"`, `singularize("foxes") == "fox"`.
5. `tests/core/model_context_spec.lua`, `describe("model_context.infer_model")`: add `it("resolves an irregular plural variable")` with its own `{ Person = true }` set: `infer_model("people", { Person = true }, nil) == "Person"`.
   Also add `it("does not singularize an uncountable receiver")`: `infer_model("news", { New = true }, nil) == nil` and `infer_model("news", { News = true }, nil) == "News"`.
6. Run `make test` and `make lint`.
7. Tick BF-061 items in `specs/story.md` and the acceptance criteria in `specs/issues/061-singularize-pluralize-irregular-words/issue.md` that this task covers (this folder only, see Notes). Leave the "other common ActiveSupport rules" criterion unticked.

## Decisions
1. Irregulars match the whole last segment, not a plain suffix like ActiveSupport. Simpler and avoids false matches inside compound words without a separator; only `human`/`salesperson`-style models differ (see Notes).
2. `movie` only; no other `-ie` words (`zombie`, `cookie`), as the story says. Adding one later is one table line.
3. Keep the story's five uncountables; ActiveSupport's other defaults (`rice`, `money`, `fish`, `sheep`, `jeans`, `police`) are not added. A later add is one line each.
4. GitHub criterion "other common ActiveSupport rules" goes to a follow-up issue. Before creating it, search existing open issues for the same topic and reuse one if found. The PR must reference #61 with `Refs #61`, not `Closes #61`, so #61 stays open until that criterion is handled or split out.

## Notes
- The planned logic was run once in a scratch Lua file against the current `singularize`/`pluralize`; every Acceptance Criteria example gave the expected result.
- Do NOT touch: the existing suffix rules in `singularize`/`pluralize`, `infer_model`, `related_files.lua`, `rails_paths.lua`, `gf.lua`, `lsp.lua`, `cmp.lua`, README. No new comments.
- No existing test changes. No existing test uses a word from the two tables (grep `people|person|movie|children` in `tests/` finds only a test title in `controller_view_spec.lua:358`).
- Deliberate difference from ActiveSupport: ActiveSupport matches irregulars as a plain suffix (`human → humen`, `salesperson → salespeople`). This plan matches whole segments only, so `human → humans`, `salesperson → salespersons`. A Rails app with a `Human` model and default inflections has table `humen`; the plugin will not find it. Accepted (rare; simpler rule, no false matches inside compound words).
- Migration lookup change (`find_migrations`, `related_files.lua:294`) is covered by the `pluralize` unit tests only; no caller-level test is added. Manual check: app with an un-annotated `app/models/person.rb` and a migration with `create_table :people`, open the model, run `:Rails related` → the migration is listed.
- Duplicate folder: `specs/issues/061-singularize-pluralize-irregular/` holds a second `issue.md` for #61 written by another process. Do NOT delete or edit it. The real spec folder is `061-singularize-pluralize-irregular-words/`; checklist step 7 ticks `issue.md` in that folder only.
- Matching is lowercase only. Inputs are paths, table names and snake_case receivers. A constant receiver such as `People` gives the same result as today (unchanged).
- `pluralize` of an already-plural word (`people → peoples`) is not handled. No caller passes a plural to `pluralize` (`related_files.lua:157,246` pass the model path). Same as today for regular words.
- Out of scope (GitHub criteria "other common ActiveSupport rules"), still wrong after this task, examples traced on current rules: `databases → databas`, `wives → wive`, `analyses → analys`. Pre-existing, unrelated to this change.
- Assumption (not tested): custom inflections in the app's `config/initializers/inflections.rb` are ignored, same as today.
- No other open task in `specs/story.md` edits `model_context.lua` singularize/pluralize. BF-056 (#56) touches `model_for_path` in the same file; whichever merges second rebases.

Review: Approved
