local terminal = require("rails-tools.ui.terminal")
local config = require("rails-tools.config")

describe("terminal", function()
  before_each(function()
    package.loaded["rails-tools.ui.terminal"] = nil
    package.loaded["rails-tools.config"] = nil
    terminal = require("rails-tools.ui.terminal")
    config = require("rails-tools.config")
    config.setup({})
  end)

  after_each(function()
    vim.cmd("silent! %bwipeout!")
    package.preload["toggleterm.terminal"] = nil
    package.loaded["toggleterm.terminal"] = nil
  end)

  describe("resolve_provider", function()
    it("returns 'native' when configured as 'native'", function()
      config.setup({ terminal = { provider = "native" } })
      assert.are.equal("native", terminal.resolve_provider())
    end)

    it("returns 'native' when configured as 'auto' and toggleterm is not installed", function()
      package.loaded["toggleterm.terminal"] = nil
      config.setup({ terminal = { provider = "auto" } })
      assert.are.equal("native", terminal.resolve_provider())
    end)

    it("returns 'toggleterm' when configured as 'auto' and toggleterm is installed", function()
      package.preload["toggleterm.terminal"] = function()
        return { Terminal = {} }
      end
      config.setup({ terminal = { provider = "auto" } })
      assert.are.equal("toggleterm", terminal.resolve_provider())
    end)

    it("returns 'native' when configured as 'toggleterm' but it is not installed", function()
      local notified = false
      vim.notify = function(msg, level)
        if msg:match("toggleterm.nvim not found") then
          notified = true
        end
      end

      config.setup({ terminal = { provider = "toggleterm" } })
      assert.are.equal("native", terminal.resolve_provider())
      assert.is_true(notified)
    end)

    it("treats unknown provider as 'auto'", function()
      config.setup({ terminal = { provider = "unknown" } })
      -- Should be native if toggleterm not installed
      assert.are.equal("native", terminal.resolve_provider())
    end)
  end)

  describe("native backend", function()
    it("opens a floating terminal by default", function()
      terminal.open("echo hello")
      local winid = vim.api.nvim_get_current_win()
      local win_config = vim.api.nvim_win_get_config(winid)
      assert.are.equal("editor", win_config.relative)
      assert.are.equal("terminal", vim.bo.buftype)
    end)

    it("honors custom float sizes", function()
      config.setup({
        terminal = {
          float = { width = 0.5, height = 0.4 }
        }
      })
      terminal.open("echo hello")
      local winid = vim.api.nvim_get_current_win()
      local win_config = vim.api.nvim_win_get_config(winid)
      assert.are.equal(math.floor(vim.o.columns * 0.5), win_config.width)
      assert.are.equal(math.floor(vim.o.lines * 0.4), win_config.height)
    end)

    it("opens horizontal terminal", function()
      config.setup({
        terminal = {
          direction = "horizontal",
          horizontal = { size = 10 }
        }
      })
      terminal.open("echo hello")
      local winid = vim.api.nvim_get_current_win()
      local win_config = vim.api.nvim_win_get_config(winid)
      assert.are.equal("", win_config.relative) -- not a float
      assert.are.equal(10, vim.api.nvim_win_get_height(winid))
    end)

    it("opens vertical terminal", function()
      config.setup({
        terminal = {
          direction = "vertical",
          vertical = { size = 30 }
        }
      })
      terminal.open("echo hello")
      local winid = vim.api.nvim_get_current_win()
      assert.are.equal(30, vim.api.nvim_win_get_width(winid))
    end)

    it("overrides config with opts.direction", function()
      config.setup({ terminal = { direction = "float" } })
      terminal.open("echo hello", { direction = "horizontal" })
      local winid = vim.api.nvim_get_current_win()
      local win_config = vim.api.nvim_win_get_config(winid)
      assert.are.equal("", win_config.relative)
    end)

    it("toggles the terminal window", function()
      terminal.open("echo hello")
      local winid = vim.api.nvim_get_current_win()
      assert.is_true(vim.api.nvim_win_is_valid(winid))

      terminal.toggle()
      assert.is_false(vim.api.nvim_win_is_valid(winid))

      terminal.toggle()
      local new_winid = vim.api.nvim_get_current_win()
      assert.is_true(vim.api.nvim_win_is_valid(new_winid))
      assert.are_not.equal(winid, new_winid)
      assert.are.equal("terminal", vim.bo.buftype)
    end)

    it("warns when toggling with no terminal", function()
      local notified = false
      vim.notify = function(msg, level)
        if msg:match("no terminal to toggle") then
          notified = true
        end
      end
      terminal.toggle()
      assert.is_true(notified)
    end)

    it("sends text to native terminal", function()
      terminal.open()
      local bufnr = vim.api.nvim_get_current_buf()

      terminal.send("echo 'test-output'")

      local found = vim.wait(2000, function()
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        for _, line in ipairs(lines) do
          if line:match("test%-output") then
            return true
          end
        end
        return false
      end)
      assert.is_true(found, "Terminal should contain 'test-output'")
    end)

    it("warns when sending with no terminal", function()
      local notified = false
      vim.notify = function(msg, level)
        if msg:match("no active terminal") then
          notified = true
        end
      end
      terminal.send("echo hi")
      assert.is_true(notified)
    end)

    it("replaces existing terminal when opening a new one", function()
      terminal.open("echo first")
      local first_buf = vim.api.nvim_get_current_buf()

      terminal.open("echo second")
      local second_buf = vim.api.nvim_get_current_buf()

      assert.are_not.equal(first_buf, second_buf)
      assert.is_false(vim.api.nvim_buf_is_valid(first_buf))
      assert.is_true(vim.api.nvim_buf_is_valid(second_buf))
    end)

    it("opens default shell when cmd is nil", function()
      terminal.open()
      assert.are.equal("terminal", vim.bo.buftype)
    end)

    it("honors cwd option", function()
      local tmpdir = vim.fn.tempname()
      vim.fn.mkdir(tmpdir, "p")
      tmpdir = vim.fn.resolve(tmpdir)

      terminal.open("pwd", { cwd = tmpdir })
      local bufnr = vim.api.nvim_get_current_buf()

      local found = vim.wait(5000, function()
        local output = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "")
        return output:find(tmpdir, 1, true) ~= nil
      end)

      -- Cleanup
      vim.fn.delete(tmpdir, "rf")

      assert.is_true(found, "Terminal output should contain " .. tmpdir)
    end)

    it("reports no active command before anything is opened", function()
      assert.is_nil(terminal.active_cmd())
      assert.is_false(terminal.is_visible())
    end)

    it("reports the active command and visibility", function()
      terminal.open("cat")

      assert.are.equal("cat", terminal.active_cmd())
      assert.is_true(terminal.is_visible())

      terminal.toggle()

      assert.are.equal("cat", terminal.active_cmd())
      assert.is_false(terminal.is_visible())
    end)

    it("clears the active command when the terminal buffer is wiped", function()
      terminal.open("cat")
      local bufnr = vim.api.nvim_get_current_buf()

      vim.api.nvim_buf_delete(bufnr, { force = true })

      assert.is_nil(terminal.active_cmd())
    end)

    it("reports a running job and asks before replacing it", function()
      terminal.open("cat")
      local orig_confirm = vim.fn.confirm
      local asked_message
      vim.fn.confirm = function(message)
        asked_message = message
        return 2
      end

      local running = terminal.is_running()
      local replace = terminal.confirm_replace()
      vim.fn.confirm = orig_confirm

      assert.is_true(running)
      assert.is_false(replace)
      assert.is_truthy(asked_message:find("cat", 1, true))
    end)

    it("replaces without asking when nothing is running", function()
      local orig_confirm = vim.fn.confirm
      local asked = false
      vim.fn.confirm = function()
        asked = true
        return 2
      end

      local replace = terminal.confirm_replace()
      vim.fn.confirm = orig_confirm

      assert.is_true(replace)
      assert.is_false(asked)
      assert.is_false(terminal.is_running())
    end)

    it("is not running after its job has finished", function()
      terminal.open("true")
      local job_id = vim.b.terminal_job_id

      vim.fn.jobwait({ job_id }, 5000)

      assert.is_false(terminal.is_running())
    end)

    it("is not visible from another tab", function()
      config.setup({ terminal = { direction = "horizontal" } })
      terminal.open("cat")
      vim.cmd("tabnew")

      assert.is_false(terminal.is_visible())
      vim.cmd("silent! tabonly!")
    end)

    it("is not visible when its window shows another buffer", function()
      terminal.open("cat")
      vim.cmd("enew")

      assert.is_false(terminal.is_visible())
    end)

    it("shows the terminal in the current tab without closing the other window", function()
      config.setup({ terminal = { direction = "horizontal" } })
      terminal.open("cat")
      local bufnr = vim.api.nvim_get_current_buf()
      local first_win = vim.api.nvim_get_current_win()
      vim.cmd("tabnew")

      terminal.show()

      assert.equals(bufnr, vim.api.nvim_get_current_buf())
      assert.is_true(terminal.is_visible())
      assert.is_true(vim.api.nvim_win_is_valid(first_win))
      vim.cmd("silent! tabonly!")
    end)

    it("warns when showing with no terminal", function()
      local notified = false
      vim.notify = function(msg)
        if msg:match("no terminal to show") then
          notified = true
        end
      end

      terminal.show()

      assert.is_true(notified)
    end)
  end)

  describe("toggleterm backend", function()
    local fake_term = {}
    local terminal_args = {}

    before_each(function()
      fake_term = {
        open = function(self, size) self.opened_with_size = size end,
        toggle = function(self) self.toggled = true end,
        shutdown = function(self) self.shutdown_called = true end,
        send = function(self, text) self.sent_text = text end,
      }

      package.preload["toggleterm.terminal"] = function()
        return {
          Terminal = {
            new = function(_, args)
              terminal_args = args
              return fake_term
            end
          }
        }
      end
      config.setup({ terminal = { provider = "toggleterm" } })
    end)

    it("calls toggleterm with correct arguments", function()
      terminal.open("rails console", { direction = "horizontal" })

      assert.are.equal("rails console", terminal_args.cmd)
      assert.are.equal("horizontal", terminal_args.direction)
      assert.are.equal(15, fake_term.opened_with_size) -- default horizontal size
    end)

    it("toggles toggleterm", function()
      terminal.open()
      terminal.toggle()
      assert.is_true(fake_term.toggled)
    end)

    it("sends text to toggleterm", function()
      terminal.open()
      terminal.send("test-cmd")
      assert.are.equal("test-cmd\n", fake_term.sent_text)
    end)

    it("shuts down existing toggleterm before opening new one", function()
      terminal.open()
      local first_term = fake_term
      terminal.open()
      assert.is_true(first_term.shutdown_called)
    end)

    it("pins provider at open time", function()
      terminal.open() -- opens with toggleterm
      config.setup({ terminal = { provider = "native" } })
      terminal.toggle() -- should still call fake_term:toggle()
      assert.is_true(fake_term.toggled)
    end)

    it("reports visibility from toggleterm is_open()", function()
      fake_term.is_open = function()
        return true
      end
      terminal.open("rails console")

      assert.are.equal("rails console", terminal.active_cmd())
      assert.is_true(terminal.is_visible())
    end)

    it("clears the active command when the toggleterm job exits", function()
      terminal.open("rails console")

      terminal_args.on_exit(fake_term)

      assert.is_nil(terminal.active_cmd())
    end)

    it("ignores the exit of a terminal that was already replaced", function()
      terminal.open("rails console")
      local old_on_exit = terminal_args.on_exit
      local old_term = fake_term
      fake_term = vim.tbl_extend("force", {}, old_term)
      terminal.open("rails runner")

      old_on_exit(old_term)

      assert.are.equal("rails runner", terminal.active_cmd())
    end)

    it("shows the toggleterm terminal", function()
      fake_term.open = function(self)
        self.shown = true
      end
      terminal.open("rails console")

      terminal.show()

      assert.is_true(fake_term.shown)
    end)
  end)
end)
