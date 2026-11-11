describe("rails-tools.commands", function()
  before_each(function()
    package.loaded["rails-tools.commands"] = nil
    pcall(vim.api.nvim_del_user_command, "Rails")
  end)

  it("registers the :Rails command", function()
    local commands = require("rails-tools.commands")
    commands.setup()
    assert.is_not_nil(vim.api.nvim_get_commands({})["Rails"])
  end)

  it("dispatches :Rails alternate to core/alternate.lua", function()
    package.loaded["rails-tools.core.alternate"] = nil
    local called = false
    package.preload["rails-tools.core.alternate"] = function()
      return { open = function() called = true end }
    end

    local commands = require("rails-tools.commands")
    commands.setup()
    vim.cmd("Rails alternate")

    assert.is_true(called)
    package.preload["rails-tools.core.alternate"] = nil
    package.loaded["rails-tools.core.alternate"] = nil
  end)

  it("dispatches :Rails console to core/console.lua", function()
    package.loaded["rails-tools.core.console"] = nil
    local called = false
    package.preload["rails-tools.core.console"] = function()
      return { open = function() called = true end }
    end

    local commands = require("rails-tools.commands")
    commands.setup()
    vim.cmd("Rails console")

    assert.is_true(called)
    package.preload["rails-tools.core.console"] = nil
    package.loaded["rails-tools.core.console"] = nil
  end)

  describe(":Rails find", function()
    local resource_types

    before_each(function()
      resource_types = {}
      package.loaded["rails-tools.core.finder"] = nil
      package.preload["rails-tools.core.finder"] = function()
        return {
          find = function(resource_type) table.insert(resource_types, resource_type) end,
        }
      end
      require("rails-tools.commands").setup()
    end)

    after_each(function()
      package.preload["rails-tools.core.finder"] = nil
      package.loaded["rails-tools.core.finder"] = nil
    end)

    it("finds the given resource type", function()
      vim.cmd("Rails find models")

      assert.are.same({ "models" }, resource_types)
    end)

    it("passes an empty resource type when none is given", function()
      vim.cmd("Rails find")

      assert.are.same({ "" }, resource_types)
    end)
  end)

  describe(":Rails runner", function()
    local calls

    before_each(function()
      calls = {}
      package.loaded["rails-tools.core.runner"] = nil
      package.preload["rails-tools.core.runner"] = function()
        return {
          run = function(code) table.insert(calls, { "run", code }) end,
          run_prompt = function() table.insert(calls, { "run_prompt" }) end,
          run_visual = function() table.insert(calls, { "run_visual" }) end,
          run_lines = function(line1, line2) table.insert(calls, { "run_lines", line1, line2 }) end,
        }
      end
      require("rails-tools.commands").setup()
    end)

    after_each(function()
      package.preload["rails-tools.core.runner"] = nil
      package.loaded["rails-tools.core.runner"] = nil
    end)

    it("runs the raw code after the subcommand", function()
      vim.cmd([[Rails runner puts "a  b"]])

      assert.are.same({ { "run", [[puts "a  b"]] } }, calls)
    end)

    it("prompts when no code is given", function()
      vim.cmd("Rails runner")

      assert.are.same({ { "run_prompt" } }, calls)
    end)

    it("runs the visual selection when the range matches it", function()
      vim.cmd("enew!")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "puts 1", "puts 2", "puts 3" })
      vim.cmd('exe "normal! 1GVj\\<Esc>"')

      vim.cmd("'<,'>Rails runner")

      assert.are.same({ { "run_visual" } }, calls)
    end)

    it("runs the typed line range when it differs from the last visual selection", function()
      vim.cmd("enew!")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "puts 1", "puts 2", "puts 3" })
      vim.cmd('exe "normal! 1GV\\<Esc>"')

      vim.cmd("2,3Rails runner")

      assert.are.same({ { "run_lines", 2, 3 } }, calls)
    end)

    it("still dispatches subcommands without arguments when a range is given", function()
      package.loaded["rails-tools.core.alternate"] = nil
      local called = false
      package.preload["rails-tools.core.alternate"] = function()
        return { open = function() called = true end }
      end

      vim.cmd("%Rails alternate")

      assert.is_true(called)
      package.preload["rails-tools.core.alternate"] = nil
      package.loaded["rails-tools.core.alternate"] = nil
    end)
  end)

  it("does not error with no subcommand", function()
    local commands = require("rails-tools.commands")
    commands.setup()
    assert.has_no.errors(function()
      vim.cmd("Rails")
    end)
  end)

  it("shows a clear error for an unknown subcommand instead of a traceback", function()
    local commands = require("rails-tools.commands")
    commands.setup()

    local notified_msg, notified_level
    local orig_notify = vim.notify
    vim.notify = function(msg, level) notified_msg = msg; notified_level = level end

    assert.has_no.errors(function()
      vim.cmd("Rails bogus")
    end)

    vim.notify = orig_notify
    assert.matches("bogus", notified_msg)
    assert.are.equal(vim.log.levels.ERROR, notified_level)
  end)

  it("calling setup() twice does not double-register the command", function()
    local commands = require("rails-tools.commands")
    commands.setup()
    assert.has_no.errors(function()
      commands.setup()
    end)
    assert.is_not_nil(vim.api.nvim_get_commands({})["Rails"])
  end)
end)
