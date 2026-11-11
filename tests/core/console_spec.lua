local console
local config

local MODULES_TO_RELOAD = {
  "rails-tools.core.console",
  "rails-tools.config",
  "rails-tools.detectors.rails",
  "rails-tools.ui.terminal",
}

describe("rails-tools.core.console", function()
  local tmp_dir
  local orig_cwd
  local orig_notify
  local notifications

  local function reload_modules()
    for _, name in ipairs(MODULES_TO_RELOAD) do
      package.loaded[name] = nil
    end
  end

  local function create_rails_project()
    vim.fn.writefile({}, tmp_dir .. "/Gemfile")
    vim.fn.mkdir(tmp_dir .. "/bin", "p")
    vim.fn.writefile({}, tmp_dir .. "/bin/rails")
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
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.cmd("silent! %bwipeout!")
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_dir, "rf")
    reload_modules()
  end)

  describe("with a fake terminal", function()
    local fake_terminal

    before_each(function()
      fake_terminal = {
        opened = {},
        opened_cwd = {},
        toggled = 0,
        shown = 0,
        active = nil,
        visible = false,
        open = function(cmd, opts)
          table.insert(fake_terminal.opened, cmd)
          table.insert(fake_terminal.opened_cwd, opts and opts.cwd)
          fake_terminal.active = cmd
          fake_terminal.visible = true
        end,
        toggle = function()
          fake_terminal.toggled = fake_terminal.toggled + 1
          fake_terminal.visible = not fake_terminal.visible
        end,
        show = function()
          fake_terminal.shown = fake_terminal.shown + 1
          fake_terminal.visible = true
        end,
        active_cmd = function()
          return fake_terminal.active
        end,
        is_visible = function()
          return fake_terminal.visible
        end,
        replace_allowed = true,
        confirm_replace = function()
          return fake_terminal.replace_allowed
        end,
      }
      package.loaded["rails-tools.ui.terminal"] = fake_terminal

      config = require("rails-tools.config")
      config.setup({})
      console = require("rails-tools.core.console")
    end)

    describe("in a Rails project", function()
      before_each(function()
        create_rails_project()
        vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
      end)

      it("opens the default console command in the Rails root", function()
        console.open()

        assert.are.same({ "rails console" }, fake_terminal.opened)
        assert.are.same({ tmp_dir }, fake_terminal.opened_cwd)
      end)

      it("opens a custom console command from config", function()
        config.setup({ console = { command = "bundle exec rails c" } })

        console.open()

        assert.are.same({ "bundle exec rails c" }, fake_terminal.opened)
      end)

      it("shows a hidden console instead of starting a new one", function()
        console.open()
        fake_terminal.visible = false

        console.open()

        assert.equals(1, #fake_terminal.opened)
        assert.equals(1, fake_terminal.shown)
        assert.equals(0, fake_terminal.toggled)
      end)

      it("does nothing when the console is already visible", function()
        console.open()

        console.open()

        assert.equals(1, #fake_terminal.opened)
        assert.equals(0, fake_terminal.toggled)
        assert.equals(0, fake_terminal.shown)
      end)

      it("keeps another running terminal when the user declines", function()
        fake_terminal.active = "rails runner 'puts 1'"
        fake_terminal.replace_allowed = false

        console.open()

        assert.equals(0, #fake_terminal.opened)
      end)

      it("replaces another active terminal with the console", function()
        fake_terminal.active = "rails runner 'puts 1'"
        fake_terminal.visible = true

        console.open()

        assert.are.same({ "rails console" }, fake_terminal.opened)
        assert.equals(0, fake_terminal.toggled)
      end)

      it("shows the active console when toggling while it is hidden", function()
        console.open()
        fake_terminal.visible = false

        console.toggle()

        assert.equals(1, #fake_terminal.opened)
        assert.equals(1, fake_terminal.shown)
        assert.equals(0, fake_terminal.toggled)
      end)

      it("toggles the active console", function()
        console.open()

        console.toggle()

        assert.equals(1, fake_terminal.toggled)
        assert.equals(1, #fake_terminal.opened)
      end)

      it("opens a new console after moving to another Rails project", function()
        console.open()
        local other_project = vim.fn.resolve(vim.fn.tempname())
        vim.fn.mkdir(other_project .. "/bin", "p")
        vim.fn.writefile({}, other_project .. "/Gemfile")
        vim.fn.writefile({}, other_project .. "/bin/rails")
        vim.cmd("cd " .. vim.fn.fnameescape(other_project))

        console.open()

        assert.are.same({ tmp_dir, other_project }, fake_terminal.opened_cwd)
        vim.fn.delete(other_project, "rf")
      end)

      it("opens the console when toggling with no console running", function()
        console.toggle()

        assert.are.same({ "rails console" }, fake_terminal.opened)
        assert.equals(0, fake_terminal.toggled)
      end)
    end)

    describe("outside a Rails project", function()
      before_each(function()
        vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
      end)

      it("warns and does not open a terminal", function()
        console.open()

        assert.equals(0, #fake_terminal.opened)
        assert.equals(1, #notifications)
        assert.equals("Rails: not a Rails project", notifications[1].msg)
        assert.equals(vim.log.levels.WARN, notifications[1].level)
      end)
    end)
  end)

  describe("with the native terminal", function()
    before_each(function()
      config = require("rails-tools.config")
      config.setup({ console = { command = "cat" }, terminal = { provider = "native" } })
      console = require("rails-tools.core.console")
      create_rails_project()
      vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
    end)

    it("keeps the same console session across toggles", function()
      console.open()
      local console_buf = vim.api.nvim_get_current_buf()
      local console_win = vim.api.nvim_get_current_win()
      assert.equals("terminal", vim.bo[console_buf].buftype)

      console.toggle()
      assert.is_false(vim.api.nvim_win_is_valid(console_win))

      console.toggle()
      assert.equals(console_buf, vim.api.nvim_get_current_buf())
      assert.equals("terminal", vim.bo[console_buf].buftype)
    end)

    it("shows the running session in a new tab without restarting it", function()
      config.setup({ console = { command = "cat" }, terminal = { provider = "native", direction = "horizontal" } })
      console.open()
      local console_buf = vim.api.nvim_get_current_buf()
      local first_tab_win = vim.api.nvim_get_current_win()
      vim.cmd("tabnew")

      console.open()

      assert.equals(console_buf, vim.api.nvim_get_current_buf())
      assert.is_true(vim.api.nvim_win_is_valid(first_tab_win))
      vim.cmd("silent! tabonly!")
    end)

    it("shows the hidden session when opened again", function()
      console.open()
      local console_buf = vim.api.nvim_get_current_buf()
      console.toggle()

      console.open()

      assert.equals(console_buf, vim.api.nvim_get_current_buf())
    end)
  end)
end)
