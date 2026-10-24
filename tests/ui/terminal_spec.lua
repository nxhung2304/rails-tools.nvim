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
  end)
end)
