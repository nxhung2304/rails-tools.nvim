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

  describe(":Rails routes", function()
    local calls

    before_each(function()
      calls = {}
      package.loaded["rails-tools.core.routes"] = nil
      package.preload["rails-tools.core.routes"] = function()
        return {
          show = function() table.insert(calls, "show") end,
          refresh = function() table.insert(calls, "refresh") end,
        }
      end
      require("rails-tools.commands").setup()
    end)

    after_each(function()
      package.preload["rails-tools.core.routes"] = nil
      package.loaded["rails-tools.core.routes"] = nil
    end)

    it("shows the routes", function()
      vim.cmd("Rails routes")

      assert.are.same({ "show" }, calls)
    end)

    it("reloads the routes with routes!", function()
      vim.cmd("Rails routes!")

      assert.are.same({ "refresh" }, calls)
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

  describe(":Rails spec", function()
    local calls
    local notifications
    local orig_notify

    before_each(function()
      calls = {}
      notifications = {}
      orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end
      package.loaded["rails-tools.config"] = nil
      package.loaded["rails-tools.integrations.rspec"] = nil
      package.preload["rails-tools.integrations.rspec"] = function()
        return {
          run_nearest = function() table.insert(calls, "run_nearest") end,
          run_file = function() table.insert(calls, "run_file") end,
          run_last = function() table.insert(calls, "run_last") end,
        }
      end
      require("rails-tools.config").setup({ modules = { rspec = true } })
      require("rails-tools.commands").setup()
    end)

    after_each(function()
      vim.notify = orig_notify
      package.preload["rails-tools.integrations.rspec"] = nil
      package.loaded["rails-tools.integrations.rspec"] = nil
      package.loaded["rails-tools.config"] = nil
    end)

    it("runs the nearest spec", function()
      vim.cmd("Rails spec nearest")

      assert.are.same({ "run_nearest" }, calls)
    end)

    it("runs the spec file", function()
      vim.cmd("Rails spec file")

      assert.are.same({ "run_file" }, calls)
    end)

    it("re-runs the last spec", function()
      vim.cmd("Rails spec last")

      assert.are.same({ "run_last" }, calls)
    end)

    it("shows the usage for a missing or unknown action", function()
      vim.cmd("Rails spec")
      vim.cmd("Rails spec bogus")

      assert.are.same({}, calls)
      assert.equals(2, #notifications)
      assert.equals("Rails: usage: :Rails spec nearest|file|last", notifications[1].msg)
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
      assert.equals("Rails: usage: :Rails spec nearest|file|last", notifications[2].msg)
    end)

    it("runs nothing and says how to enable it when modules.rspec is false", function()
      require("rails-tools.config").setup({})

      vim.cmd("Rails spec nearest")

      assert.are.same({}, calls)
      assert.equals("Rails: RSpec runner is disabled, set modules.rspec = true", notifications[1].msg)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
    end)
  end)

  describe(":Rails generate", function()
    local calls
    local notifications
    local orig_notify

    before_each(function()
      calls = {}
      notifications = {}
      orig_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end
      package.loaded["rails-tools.config"] = nil
      package.loaded["rails-tools.core.generators"] = nil
      package.preload["rails-tools.core.generators"] = function()
        return {
          run = function(args) table.insert(calls, { "run", args }) end,
          run_prompt = function() table.insert(calls, { "run_prompt" }) end,
        }
      end
      require("rails-tools.config").setup({ modules = { generators = true } })
      require("rails-tools.commands").setup()
    end)

    after_each(function()
      vim.notify = orig_notify
      package.preload["rails-tools.core.generators"] = nil
      package.loaded["rails-tools.core.generators"] = nil
      package.loaded["rails-tools.config"] = nil
    end)

    it("runs the generator arguments after the subcommand", function()
      vim.cmd("Rails generate model User name:string")

      assert.are.same({ { "run", "model User name:string" } }, calls)
    end)

    it("prompts when no arguments are given", function()
      vim.cmd("Rails generate")

      assert.are.same({ { "run_prompt" } }, calls)
    end)

    it("accepts g as a short name for generate", function()
      vim.cmd("Rails g model User name:string")
      vim.cmd("Rails g")

      assert.are.same({ { "run", "model User name:string" }, { "run_prompt" } }, calls)
    end)

    it("runs nothing and says how to enable it when modules.generators is false", function()
      require("rails-tools.config").setup({})

      vim.cmd("Rails generate model User")

      assert.are.same({}, calls)
      assert.equals("Rails: generators are disabled, set modules.generators = true", notifications[1].msg)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
    end)
  end)

  it("does not error with no subcommand", function()
    local orig_select = vim.ui.select
    vim.ui.select = function(_, _, on_choice) on_choice(nil) end
    local commands = require("rails-tools.commands")
    commands.setup()
    assert.has_no.errors(function()
      vim.cmd("Rails")
    end)
    vim.ui.select = orig_select
  end)

  it("opens the menu with no subcommand", function()
    package.loaded["rails-tools.ui.menu"] = nil
    local called = false
    package.preload["rails-tools.ui.menu"] = function()
      return { open = function() called = true end }
    end

    require("rails-tools.commands").setup()
    vim.cmd("Rails")

    assert.is_true(called)
    package.preload["rails-tools.ui.menu"] = nil
    package.loaded["rails-tools.ui.menu"] = nil
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
