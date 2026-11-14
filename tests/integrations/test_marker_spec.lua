local test_marker
local config

local MODULES_TO_RELOAD = {
  "rails-tools.integrations.test_marker",
  "rails-tools.config",
}

describe("rails-tools.integrations.test_marker", function()
  local orig_notify
  local notifications

  local function reload_modules()
    for _, name in ipairs(MODULES_TO_RELOAD) do
      package.loaded[name] = nil
    end
  end

  local function set_buffer(lines, cursor_line)
    vim.cmd("enew!")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })
  end

  local function buffer_lines()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  before_each(function()
    reload_modules()

    notifications = {}
    orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    config = require("rails-tools.config")
    config.setup({ modules = { test_marker = true } })
    test_marker = require("rails-tools.integrations.test_marker")
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.cmd("silent! %bwipeout!")
    reload_modules()
  end)

  local spec_lines = {
    "RSpec.describe User do",
    "  context 'when active' do",
    "    it 'is valid' do",
    "      expect(user).to be_valid",
    "    end",
    "  end",
    "end",
  }

  describe("is_focused()", function()
    it("returns false when the nearest example is not focused", function()
      set_buffer(spec_lines, 4)

      assert.is_false(test_marker.is_focused())
    end)

    it("returns true when the nearest example is focused", function()
      set_buffer({ "describe User do", "  fit 'works' do", "    expect(1).to eq(1)", "  end", "end" }, 3)

      assert.is_true(test_marker.is_focused())
    end)

    it("detects a focused RSpec.fdescribe line", function()
      set_buffer({ "RSpec.fdescribe User do", "end" }, 1)

      assert.is_true(test_marker.is_focused())
    end)

    it("returns nil when no example or group is above the cursor", function()
      set_buffer({ "require 'rails_helper'", "", "RSpec.describe User do", "end" }, 1)

      assert.is_nil(test_marker.is_focused())
    end)

    it("ignores words that only start with a keyword", function()
      set_buffer({ "describe User do", "  items = []", "end" }, 2)

      assert.is_false(test_marker.is_focused())
    end)

    for _, ruby_line in ipairs({ "    context = build(:context)", "    context.fail!", "    it.name", "    call(it: 1)" }) do
      it(("ignores the Ruby line %q inside an example"):format(vim.trim(ruby_line)), function()
        set_buffer({ "describe User do", "  fit 'works' do", ruby_line, "  end", "end" }, 3)

        assert.is_true(test_marker.is_focused())
      end)
    end
  end)

  describe("focus()", function()
    it("adds the focus marker to the nearest example", function()
      set_buffer(spec_lines, 4)

      assert.is_true(test_marker.focus())
      assert.are.equal("    fit 'is valid' do", buffer_lines()[3])
    end)

    it("adds the focus marker to a context on the cursor line", function()
      set_buffer(spec_lines, 2)

      test_marker.focus()

      assert.are.equal("  fcontext 'when active' do", buffer_lines()[2])
    end)

    it("adds the focus marker after the RSpec prefix", function()
      set_buffer(spec_lines, 1)

      test_marker.focus()

      assert.are.equal("RSpec.fdescribe User do", buffer_lines()[1])
    end)

    it("handles a keyword followed by a parenthesis", function()
      set_buffer({ "describe(User) do", "end" }, 1)

      test_marker.focus()

      assert.are.equal("fdescribe(User) do", buffer_lines()[1])
    end)

    it("leaves an already focused example unchanged", function()
      set_buffer({ "fit 'works' do", "end" }, 1)

      assert.is_false(test_marker.focus())
      assert.are.equal("fit 'works' do", buffer_lines()[1])
    end)

    it("warns and changes nothing when no example is found", function()
      set_buffer({ "require 'rails_helper'" }, 1)

      assert.is_false(test_marker.focus())
      assert.are.same({ "require 'rails_helper'" }, buffer_lines())
      assert.are.equal(1, #notifications)
      assert.are.equal(vim.log.levels.WARN, notifications[1].level)
    end)
  end)

  describe("unfocus()", function()
    it("removes the focus marker from the nearest example", function()
      set_buffer({ "describe User do", "  fit 'works' do", "    expect(1).to eq(1)", "  end", "end" }, 3)

      assert.is_true(test_marker.unfocus())
      assert.are.equal("  it 'works' do", buffer_lines()[2])
    end)

    it("removes the focus marker after the RSpec prefix", function()
      set_buffer({ "RSpec.fdescribe User do", "end" }, 1)

      test_marker.unfocus()

      assert.are.equal("RSpec.describe User do", buffer_lines()[1])
    end)

    it("leaves an unfocused example unchanged", function()
      set_buffer(spec_lines, 4)

      assert.is_false(test_marker.unfocus())
      assert.are.same(spec_lines, buffer_lines())
    end)
  end)

  describe("toggle()", function()
    it("focuses an unfocused example", function()
      set_buffer(spec_lines, 4)

      test_marker.toggle()

      assert.are.equal("    fit 'is valid' do", buffer_lines()[3])
    end)

    it("unfocuses a focused example", function()
      set_buffer({ "fcontext 'when active' do", "end" }, 2)

      test_marker.toggle()

      assert.are.equal("context 'when active' do", buffer_lines()[1])
    end)

    it("returns the example to its original text when run twice", function()
      set_buffer(spec_lines, 4)

      test_marker.toggle()
      test_marker.toggle()

      assert.are.same(spec_lines, buffer_lines())
    end)
  end)

  describe("when modules.test_marker is disabled", function()
    before_each(function()
      config.setup({})
    end)

    it("is_focused() warns and returns nil", function()
      set_buffer(spec_lines, 4)

      assert.is_nil(test_marker.is_focused())
      assert.are.equal(1, #notifications)
      assert.truthy(notifications[1].msg:find("modules.test_marker", 1, true))
    end)

    for _, action in ipairs({ "focus", "unfocus", "toggle" }) do
      it(action .. "() warns and does not edit the buffer", function()
        set_buffer({ "describe User do", "  fit 'works' do", "  end", "end" }, 2)
        local original_lines = buffer_lines()

        assert.is_false(test_marker[action]())
        assert.are.same(original_lines, buffer_lines())
        assert.are.equal(1, #notifications)
        assert.are.equal(vim.log.levels.WARN, notifications[1].level)
        assert.truthy(notifications[1].msg:find("modules.test_marker", 1, true))
      end)
    end
  end)
end)
