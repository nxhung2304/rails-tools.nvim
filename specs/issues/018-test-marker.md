## **Status:**
- Review: Approved
- PR: Draft

## Metadata
- **Title:** Test Marker (Focus/Unfocus)
- **Phase:** Phase 2 — Expansion v0.7
- **GitHub Issue:** #18

---

## Description
Focus or unfocus the RSpec example or group at the cursor by switching its keyword
(`it` ↔ `fit`, `describe` ↔ `fdescribe`, `context` ↔ `fcontext`, ...).

Steps:
- Find the example or group the cursor is in
- Tell whether it is focused
- Add, remove or toggle the focus marker on that line only

Scope comes from `specs/story.md` L4-018 (lines 309-314): module file, `is_focused()`, `focus()`,
`unfocus()`, `toggle()`, RSpec syntax, gated by `modules.test_marker`, tests.
The Capybara pairs were added by the user's decision at spec review.

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/integrations/test_marker.lua`
- Command: `:Rails focus` (toggles the focus of the example or group at the cursor)
- No keymap and no menu item in this task (decided at spec review)

### Supported keywords
Each pair is "unfocused ↔ focused".

| Unfocused  | Focused     | Kind    | Source |
|------------|-------------|---------|--------|
| `it`       | `fit`       | example | rspec-core |
| `specify`  | `fspecify`  | example | rspec-core |
| `example`  | `fexample`  | example | rspec-core |
| `describe` | `fdescribe` | group   | rspec-core |
| `context`  | `fcontext`  | group   | rspec-core |
| `feature`  | `ffeature`  | group   | Capybara |
| `scenario` | `fscenario` | example | Capybara |

Sources:
- rspec-core: `lib/rspec/core/example_group.rb` on the rspec/rspec main branch
  (`define_example_method :fit/:fexample/:fspecify, :focus => true`,
  `define_example_group_method :fdescribe/:fcontext, :focus => true`).
- Capybara: `lib/capybara/rspec/features.rb` on Capybara master
  (`config.alias_example_group_to :ffeature, :capybara_feature, :focus, type: :feature`,
  `config.alias_example_to :fscenario, :focus`).

Rules:
- Group keywords (`describe`, `context`, `feature` and their focused forms) may have an `RSpec.` prefix
  (`RSpec.describe` ↔ `RSpec.fdescribe`). The prefix is kept, only the keyword after it changes.
  - rspec-core `define_example_group_method` ends with `RSpec::Core::DSL.expose_example_group_alias(name)`,
    and `Configuration#alias_example_group_to` calls `define_example_group_method`
    (`lib/rspec/core/configuration.rb`, main branch), so `RSpec.fdescribe`, `RSpec.fcontext` and `RSpec.ffeature` exist.
- A line matches when, after its leading whitespace (and the optional `RSpec.` prefix for groups),
  it starts with one of the keywords above followed by a space, `(`, or the end of the line.
  So `items.each`, `it_behaves_like`, `describe_thing`, `features` and `fitness` do not match.
- Not supported, the line is not a target and is skipped while searching:
  - `focus: true` / `:focus` metadata: removing it means editing the argument list, not one keyword.
  - `focus "..."` (rspec-core alias of `fit`): unfocusing it has two valid results (`it` or `specify`).
  - `xit`, `xdescribe`, `xcontext`, `xfeature`, `xscenario`, `skip`, `pending`: skip markers, not focus markers.
  - Minitest: has no focus keyword in its core DSL (assumption — not checked against the minitest source).

### Finding the target line
Search upward from the cursor line with an indent limit, so a sibling block that already ended is
not picked. Indent is `vim.fn.indent(lnum)` (handles tabs).

A block-end line is `end` after leading whitespace, followed by optional whitespace and an optional `# comment`
(e.g. `  end`, `  end  # it "a"`). `end)` or `end.foo` are not block-end lines.

1. If the cursor line matches a keyword, it is the target.
2. Set `limit` to the cursor line's indent.
   - If the cursor line is blank, `limit` has no bound.
   - If the cursor line is a block-end line, it stays as is (the cursor is on the end of its own block).
3. Walk up one line at a time:
   - A block-end line with indent `<= limit` closes a sibling block: set `limit` to its indent minus 1.
   - A keyword line with indent `<= limit` is the target.
   - Any other line is skipped.
4. No target found: there is no target (see "When it does nothing").

Traced examples (indent in brackets):
- Cursor in the body of `it "a" do` [2] at [4]: target is `it "a"`.
- Cursor on a `let` [2] below `it "a" do` [2] ... `end` [2]: the `end` sets limit 1, target is the parent `describe` [0].
- Cursor on the `end` [2] of `it "a"`: target is `it "a"`.
- Cursor in an `items.each do` [4] ... `end` [4] block inside `it "a"`, below that `end`: the `end` sets limit 3, target is `it "a"` [2].

Known limits (accepted for this task, regex only — `grep -rn treesitter lua` finds nothing in the codebase):
- A one-line example (`it { is_expected.to ... }`, or `it "x" do ... end` on one line) has no separate block-end line,
  so a cursor on the next sibling line at the same indent targets it.
- A multi-line `{ ... }` block closes with `}`, not `end`, so it does not lower the limit.
  A cursor below a multi-line `it { ... }` sibling at the same indent targets that sibling.
- An `end` inside a heredoc or string is counted as a block end.

### Editing
- Only the keyword on the target line changes, with `vim.api.nvim_buf_set_text` on that keyword's columns.
  The rest of the line stays, and one `u` undoes it.
- The cursor stays on the same character: when the cursor is on the target line after the keyword start,
  its column shifts by the length change of the keyword (+1 for `it` → `fit`, -1 for `fit` → `it`).
  Cursor on another line: unchanged.
- `focus()` on an already focused target and `unfocus()` on an unfocused one change nothing and say nothing.
- `unfocus()` only touches the target line, not other focused lines in the file.

### Public API
```lua
---@return boolean|nil  true focused, false not focused, nil when not a spec file or no target
M.is_focused()
M.focus()
M.unfocus()
M.toggle()
```
- All four work on the current buffer and cursor, like `rspec.run_nearest()` (`lua/rails-tools/integrations/rspec.lua:53`).
- `is_focused()` is silent: it returns `nil` with no notify when the file is not a spec file or there is no target.
  Only `focus()`, `unfocus()` and `toggle()` warn.

### When it does nothing (degrade, never error)
Warnings below come from `focus()`, `unfocus()` and `toggle()` only.
- Not a spec file: same check and same message as the RSpec runner — `buftype == ""` and the name ends with `_spec.rb`,
  else WARN `Rails: not a spec file` (`lua/rails-tools/integrations/rspec.lua:17-22`).
- No target line: WARN `Rails: no example or group at the cursor`.
- Buffer is not modifiable: WARN `Rails: buffer is not modifiable`, change nothing
  (`nvim_buf_set_text` raises an error on a `nomodifiable` buffer — assumption, from Neovim API behaviour, to be confirmed by the test).
- Not in a Rails project: still works. Only buffer text changes and no command runs, so there is no need for
  `rails.root()` (the RSpec runner needs it only as the terminal `cwd`, `rspec.lua:25,49`).
- `modules.test_marker = false` (default, `lua/rails-tools/config.lua:46`): `:Rails focus` runs nothing and
  notifies WARN `Rails: test marker is disabled, set modules.test_marker = true`.
  The gate lives in the command handler, like `spec` (`commands.lua:76-80` at HEAD), `generate` (`:24-28`) and
  `grape` (`:37-41`). The integration module itself does not read `config.modules` (same as `rspec.lua`).

### Command
- Add `focus` to the `subcommands` dispatch table in `lua/rails-tools/commands.lua` (table at `:17-90` at HEAD).
- `:Rails focus` calls `require("rails-tools.integrations.test_marker").toggle()`.
- `:Rails focus <any non-empty arg>` shows ERROR `Rails: usage: :Rails focus` and does nothing,
  like `spec` and `grape` (`commands.lua:43-47`, `:82-86` at HEAD).
  The module gate is checked first, like `spec` and `grape`.
- `focus()` / `unfocus()` / `is_focused()` stay as Lua API for users' own mappings.

---

## Acceptance Criteria
- [ ] `is_focused()` returns `true` on `fit` / `fspecify` / `fexample` / `fdescribe` / `fcontext` / `ffeature` / `fscenario` targets, `false` on their unfocused forms
- [ ] `is_focused()` returns `nil` with no notify when not a spec file or there is no target
- [ ] `focus()` turns the target keyword into its focused form and keeps the rest of the line
- [ ] `unfocus()` turns the target keyword back into its unfocused form
- [ ] `toggle()` focuses an unfocused target and unfocuses a focused one
- [ ] `RSpec.describe` ↔ `RSpec.fdescribe` keeps the `RSpec.` prefix
- [ ] The cursor stays on the same character after the edit
- [ ] The target is the nearest enclosing example or group, not a sibling that already ended
- [ ] Not a spec file, no target, or a non-modifiable buffer: `focus` / `unfocus` / `toggle` warn, no change, no error
- [ ] `:Rails focus` toggles the target when `modules.test_marker = true`
- [ ] `:Rails focus <arg>` shows the usage error and does nothing
- [ ] `:Rails focus` runs nothing and says how to enable it when `modules.test_marker = false`

---

## Implementation Checklist
Work in a worktree from `main` HEAD: the main checkout has unrelated unresolved conflicts in
`lua/rails-tools/commands.lua` and `tests/commands_spec.lua`.

- [x] Create `lua/rails-tools/integrations/test_marker.lua` with the keyword table, target search and edit (Design above)
- [x] Implement `M.is_focused()` (silent)
- [x] Implement `M.focus()`
- [x] Implement `M.unfocus()`
- [x] Implement `M.toggle()`
- [x] Add `focus` to the dispatch table in `lua/rails-tools/commands.lua`, gated by `modules.test_marker`, usage error on any argument
- [x] Create `tests/integrations/test_marker_spec.lua` (setup like `tests/integrations/rspec_spec.lua`: temp `_spec.rb` file, `vim.notify` stub, `%bwipeout!` after each)
  - [x] Test focus detection: each of the 7 pairs (including Capybara `feature` / `ffeature`, `scenario` / `fscenario`), `RSpec.describe` / `RSpec.fdescribe`, no-match words (`it_behaves_like`, `items.each`, `features`, `xit`, `focus`)
  - [x] Test `is_focused()` returns `nil` with no notify when not a spec file and when there is no target
  - [x] Test target search: cursor on the keyword line, in the body, on the block's `end`, below an ended sibling, below an `end  # comment` sibling, blank line, no target
  - [x] Test focus / unfocus: keyword changes, rest of line kept, no-op when already in that state, one undo step
  - [x] Test the cursor stays on the same character after `it` → `fit` and `fit` → `it` (column +1 / -1)
  - [x] Test toggle both ways
  - [x] Test not a spec file, no target and non-modifiable buffer: `focus` / `unfocus` / `toggle` warn, no change, no error
- [x] Add `:Rails focus` cases to `tests/commands_spec.lua`, like the `:Rails spec` block (`tests/commands_spec.lua:179-249` at HEAD):
  - [x] toggles when enabled
  - [x] shows `Rails: usage: :Rails focus` and calls nothing when an argument is given
  - [x] warns and calls nothing when disabled
- [x] Update `README.md`:
  - [x] Move "Test marker" out of "Not implemented yet" (`README.md:33`)
  - [x] Add `test_marker = true` to the `modules` example (`README.md:66-70`)
  - [x] Add `:Rails focus` to the Commands list (`README.md:106-121`) with _(requires `modules.test_marker = true`)_
  - [x] Note that focus only takes effect when the project's RSpec config has `config.filter_run_when_matching :focus`

---

## Notes
- Only active when `modules.test_marker = true` (default `false`, `lua/rails-tools/config.lua:46`)
- Supports `fit`, `fspecify`, `fexample`, `fdescribe`, `fcontext`, Capybara `ffeature` and `fscenario` (and `RSpec.` prefix on groups)
- Decided at spec review:
  - Command is `:Rails focus`, toggle only. `focus()` / `unfocus()` stay as Lua API.
  - No keymap and no menu item in this task. Story L4-018 lists neither, and the default keymap table (`specs/story.md:604-617`) has no test marker row.
  - `focus: true` / `:focus` metadata and the `focus "..."` alias are not supported.
  - Capybara `feature` / `ffeature` and `scenario` / `fscenario` are supported.
  - `is_focused()` is silent.
  - `:Rails focus <arg>` shows a usage error.
- RSpec only runs the focused examples when the project has `config.filter_run_when_matching :focus`;
  otherwise the `f` prefix only adds `focus: true` metadata. The plugin does not check or change that setting.
- No Treesitter: regex on line text only, same level as the rest of the codebase.
- Out of scope: "unfocus every focused example in the file" (not in story L4-018).
