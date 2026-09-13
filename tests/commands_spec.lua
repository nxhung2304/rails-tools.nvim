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
