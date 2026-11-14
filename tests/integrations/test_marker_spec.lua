local test_marker

describe("rails-tools.integrations.test_marker", function()
  local tmp_dir
  local orig_notify
  local notifications

  local function open_spec(lines, cursor, name)
    local path = tmp_dir .. "/" .. (name or "sample_spec.rb")
    vim.fn.writefile(lines, path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    vim.api.nvim_win_set_cursor(0, cursor)
  end

  local function buffer_lines()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  before_each(function()
    package.loaded["rails-tools.integrations.test_marker"] = nil
    test_marker = require("rails-tools.integrations.test_marker")
    tmp_dir = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(tmp_dir, "p")

    notifications = {}
    orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.cmd("%bwipeout!")
    vim.fn.delete(tmp_dir, "rf")
  end)

  describe("keyword detection", function()
    local pairs_to_check = {
      { "it", "fit" },
      { "specify", "fspecify" },
      { "example", "fexample" },
      { "describe", "fdescribe" },
      { "context", "fcontext" },
      { "feature", "ffeature" },
      { "scenario", "fscenario" },
    }

    for _, pair in ipairs(pairs_to_check) do
      it("tells " .. pair[1] .. " and " .. pair[2] .. " apart", function()
        open_spec({ pair[1] .. ' "a" do', "end" }, { 1, 0 })
        assert.is_false(test_marker.is_focused())

        open_spec({ pair[2] .. ' "a" do', "end" }, { 1, 0 })
        assert.is_true(test_marker.is_focused())
      end)
    end

    it("accepts the RSpec prefix on groups", function()
      open_spec({ 'RSpec.describe "a" do', "end" }, { 1, 0 })
      assert.is_false(test_marker.is_focused())

      open_spec({ 'RSpec.fdescribe "a" do', "end" }, { 1, 0 })
      assert.is_true(test_marker.is_focused())
    end)

    it("accepts a call with parentheses and a bare keyword", function()
      open_spec({ 'it("a") do', "end" }, { 1, 0 })
      assert.is_false(test_marker.is_focused())

      open_spec({ "it" }, { 1, 0 })
      assert.is_false(test_marker.is_focused())
    end)

    local non_targets = {
      "  it_behaves_like :thing",
      "  items.each do |item|",
      "  features",
      "  fitness",
      "  describe_thing",
      '  xit "a" do',
      '  focus "a" do',
      "  RSpec.it",
    }

    for _, text in ipairs(non_targets) do
      it("does not treat `" .. text .. "` as a target", function()
        open_spec({ text }, { 1, 0 })

        assert.is_nil(test_marker.is_focused())
      end)
    end
  end)

  describe("is_focused", function()
    it("returns nil without a notification when not a spec file", function()
      open_spec({ 'it "a" do', "end" }, { 1, 0 }, "sample.rb")

      assert.is_nil(test_marker.is_focused())
      assert.are.same({}, notifications)
    end)

    it("returns nil without a notification when there is no target", function()
      open_spec({ "let(:a) { 1 }" }, { 1, 0 })

      assert.is_nil(test_marker.is_focused())
      assert.are.same({}, notifications)
    end)
  end)

  describe("target search", function()
    local lines = {
      'RSpec.describe "thing" do',
      "  let(:a) { 1 }",
      "",
      '  it "first" do',
      "    expect(a).to eq(1)",
      "  end",
      "",
      '  it "second" do',
      "    items.each do |item|",
      "      item",
      "    end",
      "    expect(a).to eq(1)",
      "  end  # it second",
      "",
      "  let(:b) { 2 }",
      "end",
    }

    local function focus_at(lnum)
      open_spec(vim.deepcopy(lines), { lnum, 0 })
      test_marker.focus()

      return buffer_lines()
    end

    it("targets the keyword line itself", function()
      assert.equals('  fit "first" do', focus_at(4)[4])
    end)

    it("targets the example when the cursor is in its body", function()
      assert.equals('  fit "first" do', focus_at(5)[4])
    end)

    it("targets the example when the cursor is on its end", function()
      assert.equals('  fit "first" do', focus_at(6)[4])
    end)

    it("targets the example when the cursor is below an inner block that ended", function()
      assert.equals('  fit "second" do', focus_at(12)[8])
    end)

    it("targets the parent group below an ended sibling", function()
      assert.equals('RSpec.fdescribe "thing" do', focus_at(15)[1])
    end)

    it("targets the parent group below a sibling whose end has a comment", function()
      assert.equals('RSpec.fdescribe "thing" do', focus_at(15)[1])
      assert.equals('  it "second" do', buffer_lines()[8])
    end)

    it("targets the parent group from a blank line between siblings", function()
      assert.equals('RSpec.fdescribe "thing" do', focus_at(7)[1])
    end)

    it("targets the group from the group body above any example", function()
      assert.equals('RSpec.fdescribe "thing" do', focus_at(2)[1])
    end)

    it("targets the parent group from a let block body below a one-line example", function()
      open_spec({
        "describe Foo do",
        "  it { is_expected.to be }",
        "",
        "  let(:x) do",
        "    foo",
        "  end",
        "end",
      }, { 5, 0 })

      test_marker.focus()

      assert.equals("fdescribe Foo do", buffer_lines()[1])
      assert.equals("  it { is_expected.to be }", buffer_lines()[2])
    end)

    it("does nothing and warns when there is no target", function()
      open_spec({ "let(:a) { 1 }", "puts a" }, { 2, 0 })

      test_marker.focus()

      assert.are.same({ "let(:a) { 1 }", "puts a" }, buffer_lines())
      assert.equals("Rails: no example or group at the cursor", notifications[1].msg)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
    end)
  end)

  describe("focus and unfocus", function()
    it("focuses the keyword and keeps the rest of the line", function()
      open_spec({ '  it "does a thing", :slow do', "  end" }, { 1, 0 })

      test_marker.focus()

      assert.are.same({ '  fit "does a thing", :slow do', "  end" }, buffer_lines())
    end)

    it("unfocuses the keyword and keeps the rest of the line", function()
      open_spec({ 'RSpec.fdescribe "thing" do', "end" }, { 1, 0 })

      test_marker.unfocus()

      assert.are.same({ 'RSpec.describe "thing" do', "end" }, buffer_lines())
    end)

    it("changes nothing and says nothing when already in that state", function()
      open_spec({ 'fit "a" do', "end" }, { 1, 0 })
      test_marker.focus()
      assert.are.same({ 'fit "a" do', "end" }, buffer_lines())

      open_spec({ 'it "a" do', "end" }, { 1, 0 })
      test_marker.unfocus()
      assert.are.same({ 'it "a" do', "end" }, buffer_lines())

      assert.are.same({}, notifications)
    end)

    it("only touches the target line", function()
      open_spec({ 'fdescribe "a" do', '  fit "b" do', "  end", "end" }, { 4, 0 })

      test_marker.unfocus()

      assert.are.same({ 'describe "a" do', '  fit "b" do', "  end", "end" }, buffer_lines())
    end)

    it("is undone by one undo", function()
      open_spec({ 'it "a" do', "end" }, { 1, 0 })

      test_marker.focus()
      vim.cmd("undo")

      assert.are.same({ 'it "a" do', "end" }, buffer_lines())
    end)
  end)

  describe("cursor position", function()
    it("moves one column right on the same character after it to fit", function()
      open_spec({ '  it "a" do', "  end" }, { 1, 6 })

      test_marker.focus()

      assert.are.same({ 1, 7 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("moves one column left on the same character after fit to it", function()
      open_spec({ '  fit "a" do', "  end" }, { 1, 7 })

      test_marker.unfocus()

      assert.are.same({ 1, 6 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("leaves the cursor unchanged when it is on another line", function()
      open_spec({ '  it "a" do', "    expect(1)", "  end" }, { 2, 4 })

      test_marker.focus()

      assert.are.same({ 2, 4 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("leaves the cursor on the keyword start unchanged", function()
      open_spec({ 'fit "a" do', "end" }, { 1, 0 })

      test_marker.unfocus()

      assert.are.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("leaves the cursor unchanged when it is before the keyword", function()
      open_spec({ '  it "a" do', "  end" }, { 1, 0 })

      test_marker.focus()

      assert.are.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
    end)
  end)

  describe("toggle", function()
    it("focuses an unfocused target", function()
      open_spec({ 'it "a" do', "end" }, { 1, 0 })

      test_marker.toggle()

      assert.are.same({ 'fit "a" do', "end" }, buffer_lines())
    end)

    it("unfocuses a focused target", function()
      open_spec({ 'fit "a" do', "end" }, { 1, 0 })

      test_marker.toggle()

      assert.are.same({ 'it "a" do', "end" }, buffer_lines())
    end)
  end)

  describe("when it cannot change anything", function()
    for _, action in ipairs({ "focus", "unfocus", "toggle" }) do
      it(action .. " warns for a file that is not a spec", function()
        open_spec({ 'it "a" do', "end" }, { 1, 0 }, "sample.rb")

        assert.has_no.errors(test_marker[action])

        assert.are.same({ 'it "a" do', "end" }, buffer_lines())
        assert.equals("Rails: not a spec file", notifications[1].msg)
        assert.equals(vim.log.levels.WARN, notifications[1].level)
      end)

      it(action .. " warns when there is no target", function()
        open_spec({ "puts 1" }, { 1, 0 })

        assert.has_no.errors(test_marker[action])

        assert.equals("Rails: no example or group at the cursor", notifications[1].msg)
      end)
    end

    local non_modifiable_cases = {
      { action = "focus", line = 'it "a" do' },
      { action = "unfocus", line = 'fit "a" do' },
      { action = "toggle", line = 'it "a" do' },
    }

    for _, case in ipairs(non_modifiable_cases) do
      it(case.action .. " warns and changes nothing in a non-modifiable buffer", function()
        open_spec({ case.line, "end" }, { 1, 0 })
        vim.bo.modifiable = false

        assert.has_no.errors(test_marker[case.action])

        assert.are.same({ case.line, "end" }, buffer_lines())
        assert.equals("Rails: buffer is not modifiable", notifications[1].msg)
        assert.equals(vim.log.levels.WARN, notifications[1].level)
      end)
    end
  end)
end)
