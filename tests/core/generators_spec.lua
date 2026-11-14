local generators

local MODULES_TO_RELOAD = {
  "rails-tools.core.generators",
  "rails-tools.config",
  "rails-tools.detectors.rails",
  "rails-tools.ui.terminal",
}

describe("rails-tools.core.generators", function()
  local tmp_dir
  local orig_cwd
  local orig_notify
  local orig_input
  local notifications
  local opened
  local replace_allowed

  local function reload_modules()
    for _, name in ipairs(MODULES_TO_RELOAD) do
      package.loaded[name] = nil
    end
  end

  local function create_rails_project(root)
    vim.fn.mkdir(root .. "/bin", "p")
    vim.fn.writefile({}, root .. "/Gemfile")
    vim.fn.writefile({}, root .. "/bin/rails")
  end

  before_each(function()
    orig_cwd = vim.fn.getcwd()
    tmp_dir = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(tmp_dir, "p")
    reload_modules()

    notifications = {}
    orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end
    orig_input = vim.ui.input

    opened = {}
    replace_allowed = true
    package.loaded["rails-tools.ui.terminal"] = {
      open = function(cmd, opts)
        table.insert(opened, { cmd = cmd, cwd = opts and opts.cwd })
      end,
      confirm_replace = function()
        return replace_allowed
      end,
    }

    require("rails-tools.config").setup({})
    generators = require("rails-tools.core.generators")
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.ui.input = orig_input
    vim.cmd("silent! %bwipeout!")
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_dir, "rf")
    reload_modules()
  end)

  describe("in a Rails project", function()
    before_each(function()
      create_rails_project(tmp_dir)
      vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
    end)

    it("generates a model in the Rails root", function()
      generators.run("model User name:string email:string")

      assert.are.same({ { cmd = "rails generate model User name:string email:string", cwd = tmp_dir } }, opened)
    end)

    it("generates a controller", function()
      generators.run("controller Admin::Users index show")

      assert.equals("rails generate controller Admin::Users index show", opened[1].cmd)
    end)

    it("generates a migration", function()
      generators.run("migration AddAgeToUsers age:integer")

      assert.equals("rails generate migration AddAgeToUsers age:integer", opened[1].cmd)
    end)

    it("uses the generator command from config", function()
      require("rails-tools.config").setup({ generators = { command = "bin/rails generate" } })

      generators.run("model Post")

      assert.equals("bin/rails generate model Post", opened[1].cmd)
    end)

    it("trims surrounding spaces from the arguments", function()
      generators.run("  model Post  ")

      assert.equals("rails generate model Post", opened[1].cmd)
    end)

    it("runs in the Rails project of the current file, not the cwd", function()
      local other_project = vim.fn.resolve(vim.fn.tempname())
      create_rails_project(other_project)
      vim.fn.mkdir(other_project .. "/app/models", "p")
      vim.fn.writefile({}, other_project .. "/app/models/user.rb")
      vim.cmd("edit " .. vim.fn.fnameescape(other_project .. "/app/models/user.rb"))

      generators.run("model Post")
      vim.cmd("bwipeout!")
      vim.fn.delete(other_project, "rf")

      assert.equals(other_project, opened[1].cwd)
    end)

    it("does not run when the user keeps the running terminal", function()
      replace_allowed = false

      generators.run("model Post")

      assert.equals(0, #opened)
    end)

    it("warns and runs nothing for empty arguments", function()
      generators.run("   ")
      generators.run(nil)

      assert.equals(0, #opened)
      assert.equals(2, #notifications)
      assert.equals("Rails: no generator given", notifications[1].msg)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
    end)

    it("runs the arguments typed in the prompt", function()
      local prompt_text
      vim.ui.input = function(opts, on_confirm)
        prompt_text = opts.prompt
        on_confirm("model Post title:string")
      end

      generators.run_prompt()

      assert.equals("Rails generate: ", prompt_text)
      assert.equals("rails generate model Post title:string", opened[1].cmd)
    end)

    it("does nothing when the prompt is cancelled", function()
      vim.ui.input = function(_, on_confirm)
        on_confirm(nil)
      end

      generators.run_prompt()

      assert.equals(0, #opened)
      assert.equals(0, #notifications)
    end)
  end)

  describe("outside a Rails project", function()
    it("warns and runs nothing", function()
      vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))

      generators.run("model Post")

      assert.equals(0, #opened)
      assert.equals("Rails: not a Rails project", notifications[1].msg)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
    end)
  end)
end)
