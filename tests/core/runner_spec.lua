local runner
local config

local MODULES_TO_RELOAD = {
  "rails-tools.core.runner",
  "rails-tools.config",
  "rails-tools.detectors.rails",
  "rails-tools.ui.terminal",
}

describe("rails-tools.core.runner", function()
  local tmp_dir
  local orig_cwd
  local orig_notify
  local orig_input
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

  local function select_text(lines, keys)
    vim.cmd("enew!")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.cmd('exe "normal! ' .. keys .. '\\<Esc>"')
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
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.ui.input = orig_input
    vim.cmd("silent! %bwipeout!")
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_dir, "rf")
    reload_modules()
  end)

  describe("with a fake terminal", function()
    local opened

    before_each(function()
      opened = {}
      package.loaded["rails-tools.ui.terminal"] = {
        open = function(cmd, opts)
          table.insert(opened, { cmd = cmd, cwd = opts and opts.cwd })
        end,
      }

      config = require("rails-tools.config")
      config.setup({})
      runner = require("rails-tools.core.runner")
    end)

    describe("in a Rails project", function()
      before_each(function()
        create_rails_project()
        vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
      end)

      it("runs code with the default runner command in the Rails root", function()
        runner.run("puts User.count")

        assert.are.same({ { cmd = "rails runner 'puts User.count'", cwd = tmp_dir } }, opened)
      end)

      it("uses a custom runner command from config", function()
        config.setup({ runner = { command = "bin/rails runner" } })

        runner.run("puts 1")

        assert.equals("bin/rails runner 'puts 1'", opened[1].cmd)
      end)

      it("shell-escapes single quotes in the code", function()
        runner.run("puts 'hi'")

        assert.equals([[rails runner 'puts '\''hi'\''']], opened[1].cmd)
      end)

      it("warns and runs nothing for empty code", function()
        runner.run("   ")

        assert.equals(0, #opened)
        assert.equals("Rails: no code to run", notifications[1].msg)
        assert.equals(vim.log.levels.WARN, notifications[1].level)
      end)

      it("warns and runs nothing for nil code", function()
        runner.run(nil)

        assert.equals(0, #opened)
        assert.equals("Rails: no code to run", notifications[1].msg)
      end)

      it("runs the code typed in the prompt", function()
        local prompt_text
        vim.ui.input = function(opts, on_confirm)
          prompt_text = opts.prompt
          on_confirm("puts 2")
        end

        runner.run_prompt()

        assert.equals("Rails runner: ", prompt_text)
        assert.equals("rails runner 'puts 2'", opened[1].cmd)
      end)

      it("does nothing when the prompt is cancelled", function()
        vim.ui.input = function(_, on_confirm)
          on_confirm(nil)
        end

        runner.run_prompt()

        assert.equals(0, #opened)
        assert.equals(0, #notifications)
      end)

      it("runs a characterwise selection across lines", function()
        select_text({ "x = puts 1", "puts 2 # end" }, "1G5|vj6|")

        runner.run_visual()

        assert.equals("rails runner " .. vim.fn.shellescape("puts 1\nputs 2"), opened[1].cmd)
      end)

      it("runs whole lines for a linewise selection", function()
        select_text({ "puts 1", "puts 2", "puts 3" }, "1GVj")

        runner.run_visual()

        assert.equals("rails runner " .. vim.fn.shellescape("puts 1\nputs 2"), opened[1].cmd)
      end)

      it("keeps a multibyte last character whole", function()
        select_text({ "puts 'héé'" }, "1G0vf'f'h")

        runner.run_visual()

        assert.equals("rails runner " .. vim.fn.shellescape("puts 'héé"), opened[1].cmd)
      end)
    end)

    describe("outside a Rails project", function()
      before_each(function()
        vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
      end)

      it("warns and does not open a terminal", function()
        runner.run("puts 1")

        assert.equals(0, #opened)
        assert.equals("Rails: not a Rails project", notifications[1].msg)
        assert.equals(vim.log.levels.WARN, notifications[1].level)
      end)
    end)
  end)

  describe("with the native terminal", function()
    before_each(function()
      config = require("rails-tools.config")
      config.setup({ runner = { command = "echo" }, terminal = { provider = "native" } })
      runner = require("rails-tools.core.runner")
      create_rails_project()
      vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
    end)

    it("shows the command output in the terminal", function()
      runner.run("runner-output-check")
      local bufnr = vim.api.nvim_get_current_buf()

      local found = vim.wait(5000, function()
        local output = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
        return output:find("runner-output-check", 1, true) ~= nil
      end)

      assert.is_true(found)
    end)
  end)
end)
