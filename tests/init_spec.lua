describe("rails-tools.init", function()
  before_each(function()
    package.loaded["rails-tools"] = nil
    package.loaded["rails-tools.config"] = nil
    package.loaded["rails-tools.commands"] = nil
    package.loaded["rails-tools.integrations.lsp"] = nil
    package.loaded["rails-tools.integrations.cmp"] = nil
  end)

  it("setup() does not error with no opts", function()
    local rails_tools = require("rails-tools")
    assert.has_no.errors(function()
      rails_tools.setup()
    end)
  end)

  it("setup() deep-merges user opts over defaults", function()
    local rails_tools = require("rails-tools")
    local config = require("rails-tools.config")
    rails_tools.setup({ keymaps = { prefix = "<leader>x" } })
    local current = config.get()
    assert.are.equal("<leader>x", current.keymaps.prefix)
    assert.are.equal(true, current.keymaps.enabled)
  end)

  it("registers the :Rails command", function()
    local rails_tools = require("rails-tools")
    rails_tools.setup()
    assert.is_not_nil(vim.api.nvim_get_commands({})["Rails"])
  end)

  it("calling setup() twice does not error or re-register", function()
    local rails_tools = require("rails-tools")
    rails_tools.setup()
    assert.has_no.errors(function()
      rails_tools.setup()
    end)
  end)
end)
