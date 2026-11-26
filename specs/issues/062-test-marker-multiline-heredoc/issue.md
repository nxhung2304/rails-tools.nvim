[ISSUE-#62] Test marker picks the wrong block for multi-line it(...) and fails after a heredoc
GitHub Issue: #62
State: OPEN
Labels: bug
Assignees: 
Source: GitHub

## Problem
The marker finds the enclosing example by walking up and comparing indentation. Two real RSpec layouts break it (both reproduced by calling `require("rails-tools.integrations.test_marker").toggle()` headless on Neovim 0.9.5).

### Case 1 — example with arguments split over several lines
```ruby
RSpec.describe User do
  it(
    "multi line args"
  ) do
    expect(true).to be true   # cursor here
  end
end
```
Result: `RSpec.describe` becomes `RSpec.fdescribe` — the whole group is focused instead of the example.

### Case 2 — heredoc with a dedented `end` line inside an example
```ruby
RSpec.describe User do
  it "uses heredoc" do
    sql = <<~SQL
      select 1
end
    SQL
    expect(sql).to be_present   # cursor here
  end
end
```
Result: "Rails: no example or group at the cursor". After this heredoc, every example below it in the file also fails the same way, because the column-0 `end` lowers the search limit below every outer block.

## Evidence
- `lua/rails-tools/integrations/test_marker.lua:92-120` (`find_target`): the `) do` line at lower indent lowers the limit past the `it(` line (case 1); any line matching `^%s*end` is treated as a block end, including heredoc content (case 2).

## Acceptance criteria
- [ ] Case 1 focuses the `it(` line.
- [ ] Case 2 focuses the `it "uses heredoc"` line, and examples below the heredoc still work.
- [ ] Existing marker tests still pass; both cases added as regression tests.
