# Implement plan — BF-062 Test marker: multi-line `it(...)` and heredoc

## Related
- [Original issue](./issue.md)

Source: `specs/issues/062-test-marker-multiline-heredoc/issue.md` (GitHub #62).

## Description
Both cases reproduced headless with `toggle()` on current `main`.
- `find_target` (`lua/rails-tools/integrations/test_marker.lua:88-116`) walks up and narrows `limit` by indentation.
- Case 1: cursor line indent 4 → `  ) do` (indent 2) is not a target and `2 < 4`, so `limit = 1` (`test_marker.lua:108-109`) → `  it(` (indent 2) is skipped → `RSpec.describe` is focused.
- Case 2: the heredoc body line `end` at column 0 matches `is_block_end` (`test_marker.lua:65-67`) → `limit = -1` (`test_marker.lua:101-102`) → no line can match → "Rails: no example or group at the cursor".
- Effect below the heredoc: any lookup that must climb past it fails (blank line at group level, body of a `before`/`let` block). Reproduced. A cursor inside a later example body still works, because that `it` line is found before the heredoc is reached (reproduced). The issue's "every example below fails" is broader than this.

## Design
- Closing-bracket line that opens a block (starts with `)`/`]`/`}` and, after dropping a trailing `# comment`, ends with `do`, `do |args|`, `{` or `{ |args|`): the cursor is inside that block, so its opener at the same indent is the enclosing line.
  - Set `limit = indent` (lines inside the brackets are deeper and skipped; the opener at the same indent is checked).
  - The next checked line is that opener. If it is a target it is returned (Case 1). If not (e.g. `shared_examples(` … `) do`), `limit = indent - 1`, as today, so a sibling at that indent is never picked.
- Every other closing-bracket line (`)`, `}`, `]`, `}.to raise_error`, …) keeps today's rule: it is handled like any non-target line. So a blank line below a multi-line `let(:x) { … }` or a multi-line `it(` without a block still finds the parent group, exactly as today.
- Heredoc bodies: before the upward walk, scan lines `1 .. cursor_lnum - 1` once, forward, and collect the line numbers inside heredoc bodies. The upward walk skips those lines.
  - Opener: every `<<[~-]?["'`]?IDENT` on a line, in order (supports `f(<<~A, <<~B)`), only when the character before `<<` is not a letter, digit, `_`, `)`, `]` or `}` (line start counts as allowed). So `a << b` (space after `<<`) and `list<<item` (identifier right before `<<`) are not heredocs.
  - Lines that start with `#` are not scanned for openers.
  - Body ends at the line whose trimmed text equals the identifier; the terminator line is also skipped.
- Only `test_marker.lua` changes. `parse_keyword`, `is_block_end`, `target_at`, focus/unfocus logic untouched.
- Verified on a scratch copy (not in repo) with the exact code below: all 59 existing marker tests and the 11 new tests pass (70/70), full `make test` and `make lint` clean. The 3 bracket regression tests fail with the earlier design (`limit = indent` on every closing-bracket line) and pass with this one; 6 of the new tests fail on current `main`.

## Acceptance Criteria
- [ ] Case 1 focuses the `it(` line.
- [ ] Case 2 focuses `it "uses heredoc"`; lookups below the heredoc (blank group line, `before` body) find the group.
- [ ] A blank line below a multi-line `let(:x) { … }` or a multi-line `it(` without a block still focuses the parent group (today's behaviour).
- [ ] Existing marker tests pass unchanged; regression tests below added; `make test` and `make lint` pass.

## Implementation Checklist
1. `lua/rails-tools/integrations/test_marker.lua`, after `NON_CALL_FOLLOWER_PATTERN`, add constants:
   ```lua
   local HEREDOC_OPENER_PATTERN = "[^%w_%)%]}]<<[~-]?[\"'`]?([%a_][%w_]*)"
   local COMMENT_LINE_PATTERN = "^%s*#"
   local CLOSING_BRACKET_LINE_PATTERN = "^%s*[%)%]}]"
   local TRAILING_COMMENT_PATTERN = "%s+#.*$"
   local BLOCK_OPENER_SUFFIX_PATTERNS = { "[%s%)%]}]do$", "[%s%)%]}]do%s*|[^|]*|$", "{$", "{%s*|[^|]*|$" }
   ```
2. Same file, add above `find_target`:
   ```lua
   ---@param text string
   ---@return boolean
   local function opens_block_after_closing_bracket(text)
     if not text:match(CLOSING_BRACKET_LINE_PATTERN) then
       return false
     end

     local code = vim.trim((text:gsub(TRAILING_COMMENT_PATTERN, "")))
     for _, pattern in ipairs(BLOCK_OPENER_SUFFIX_PATTERNS) do
       if code:match(pattern) then
         return true
       end
     end

     return false
   end

   ---@param last_lnum integer
   ---@return table<integer, boolean>
   local function heredoc_body_lines(last_lnum)
     local body_lines = {}
     local pending_terminators = {}
     for lnum, text in ipairs(vim.api.nvim_buf_get_lines(0, 0, last_lnum, false)) do
       if #pending_terminators > 0 then
         body_lines[lnum] = true
         if vim.trim(text) == pending_terminators[1] then
           table.remove(pending_terminators, 1)
         end
       elseif not text:match(COMMENT_LINE_PATTERN) then
         for identifier in (" " .. text):gmatch(HEREDOC_OPENER_PATTERN) do
           table.insert(pending_terminators, identifier)
         end
       end
     end
     return body_lines
   end
   ```
3. In `find_target`, before the `for` loop:
   ```lua
   local skipped_lines = heredoc_body_lines(cursor_lnum - 1)
   local awaiting_bracket_opener = false
   ```
4. Loop condition becomes `if indent <= limit and not text:match("^%s*$") and not skipped_lines[lnum] then`.
5. Loop body becomes:
   ```lua
   if is_block_end(text) then
     limit = indent - 1
     awaiting_bracket_opener = false
   elseif opens_block_after_closing_bracket(text) then
     limit = indent
     awaiting_bracket_opener = true
   else
     local target = target_at(lnum)
     if target then
       return target
     end
     if indent < limit or awaiting_bracket_opener then
       limit = indent - 1
     end
     awaiting_bracket_opener = false
   end
   ```
6. `tests/integrations/test_marker_spec.lua`, inside `describe("target search")`, before `it("does nothing and warns when there is no target")`, add a local helper `focus_lines_at(spec_lines, lnum)` (open_spec + `test_marker.focus()` + return `buffer_lines()`), the issue's Case 1 lines as `multi_line_example` and Case 2 lines as `heredoc_example`, and these tests (each opens the buffer once; opening the same modified file twice in one test fails with E37):
   - `it("targets an example whose arguments span several lines")`: Case 1, cursor line 5 → line 2 is `  fit(`, line 1 unchanged.
   - `it("targets a multi-line example whose block takes arguments and has a comment")`: `describe X do` / `  it(` / `    "a"` / `  ) do |record| # note` / `    record` / `  end` / `end`, cursor line 5 → line 2 is `  fit(`. (Do not use `example` as the body word: it is a keyword and would be targeted itself.)
   - `it("targets the parent group when a multi-line call that opens a block is not a target")`: `describe X do` / `  it { is_expected.to be }` / `  shared_examples(` / `    "a"` / `  ) do` / `    foo` / `  end` / `end`, cursor line 6 → `fdescribe X do`, line 2 unchanged.
   - `it("targets the parent group from a blank line below a multi-line let")`: `describe User do` / `  it { is_expected.to be_valid }` / `  let(:params) {` / `    { a: 1 }` / `  }` / `""` / `end`, cursor line 6 → `fdescribe User do`, line 2 unchanged.
   - `it("targets the parent group from a blank line below a multi-line example without a block")`: `describe User do` / `  it "a" do` / `  end` / `  it(` / `    "pending"` / `  )` / `""` / `end`, cursor line 7 → `fdescribe User do`, line 4 is still `  it(`.
   - `it("targets the example around a heredoc with a dedented end line")`: Case 2, cursor line 7 (`expect(sql)`) → line 2 is `  fit "uses heredoc" do`.
   - `it("targets the parent group from a before block body below an example that has such a heredoc")`: Case 2 with the last `end` replaced by `""`, `"  before do"`, `"    x"`, `"  end"`, `"end"`; cursor line 11 (`    x`) → `RSpec.fdescribe User do`.
   - `it("targets the parent group from a blank line below an example that has such a heredoc")`: same lines, cursor line 9 (blank) → `RSpec.fdescribe User do`.
   - `it("skips the bodies of two heredocs opened on one line")`: `describe X do` / `  it "h" do` / `    f(<<~A, <<~B)` / `end` / `    A` / `end` / `    B` / `  end` / `""` / `end`, cursor line 9 → `fdescribe X do`.
   - `it("does not treat a shovel operator as a heredoc")`: `describe X do` / `  it "h" do` / `    a << b` / `  end` / `""` / `end`, cursor line 5 → `fdescribe X do`.
   - `it("does not treat a shovel operator without spaces as a heredoc")`: `describe X do` / `  it "a" do` / `    list<<item` / `  end` / `""` / `  it "b" do` / `    foo` / `  end` / `end`, cursor line 7 → line 6 is `  fit "b" do`, line 2 unchanged.
7. Run `make test` and `make lint`.
8. Tick the BF-062 items in `specs/story.md:411-413` and the acceptance criteria in `issue.md`.

## Risks to test
- Closing-bracket lines: only a line that starts with `)`/`]`/`}` and ends with a block opener (`do`, `do |x|`, `{`, `{ |x|`, optional trailing comment) changes behaviour. Every other closing-bracket line goes through today's logic, so a blank line or a group-level line below a multi-line `let(:x) { … }`, `let(:x) do [ … ]` or `it( … )` without a block still finds the parent group (covered by the 2 blank-line tests). Note: the existing sibling tests all end with `end`, so they never covered bracket lines; the new tests do.
- A block-opening closing-bracket line whose opener is not a target (`shared_examples(` … `) do`) drops the limit below that indent right after the opener, so a one-line sibling above is not picked (covered by a test; same result as today).
- A trailing comment containing ` #` after the block opener is stripped by a simple pattern; a string with ` #` on such a line could hide the `do`. Then the line falls back to today's behaviour (focuses the group, not a wrong example).
- Heredoc opener inside a string literal (`"a <<~X"`) on a non-comment line: its "body" swallows lines until a line equals `X`, possibly up to the cursor; lines it swallows are skipped, so the marker can land on an example above the real one (a wrong line is edited, not just a warning). Rare in spec files; accepted (see Decisions).
- Unspaced shovel (`list<<item`): not a heredoc under the new opener rule (covered by a test). Remaining gap: a value ending in a quote right before `<<` (`"a"<<b`) is still read as a heredoc opener; accepted, rare in spec files and normally reformatted by RuboCop's operator spacing rule.
- Cost: one extra read of lines `1 .. cursor` per call. `is_focused` has no in-repo caller today (only `:Rails` toggle at `commands.lua:63` calls the module), so no statusline cost now.

## Notes
- Do NOT touch: `parse_keyword`, `is_block_end`, `target_at`, `write_focus`, `change_focus`, public API. No new comments.
- Existing tests are not changed.

## Decisions made without you
1. Plain `<<SQL` (no `~`/`-`) needs its terminator at column 0 in Ruby; the plan accepts an indented terminator for every form. Decided: accept — simpler, and spec files almost always use `<<~`.
2. Cursor placed inside a heredoc body (e.g. on the column-0 `end` itself) is not in the acceptance criteria and still behaves as today. Decided: out of scope; file a follow-up only if a user hits it.
3. Heredoc openers inside string literals are not filtered (only comment lines are). Decided: accept; filtering strings needs a tokenizer, beyond this fix.
4. Unspaced shovel `list<<item`: fixed in this change (one character class in the opener pattern), not left as a limitation.

Review: Approved
