describe("rails-tools.init", function()
  before_each(function()
    package.loaded["rails-tools"] = nil
    package.loaded["rails-tools.config"] = nil
    package.loaded["rails-tools.commands"] = nil
    package.loaded["rails-tools.integrations.lsp"] = nil
    package.loaded["rails-tools.integrations.cmp"] = nil
    package.loaded["rails-tools.keymaps"] = nil
  end)

  after_each(function()
    package.loaded["rails-tools.core.gf"] = nil
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

  it("registers the default keymaps", function()
    local orig_mapleader = vim.g.mapleader
    vim.g.mapleader = ","
    local rails_tools = require("rails-tools")

    rails_tools.setup()

    local menu_mapping = vim.fn.maparg(",rr", "n", false, true)
    pcall(vim.keymap.del, "n", ",rr")
    vim.g.mapleader = orig_mapleader
    assert.are.equal("<Cmd>Rails<CR>", menu_mapping.rhs)
  end)

  it("setup() runs again after a sub-module error", function()
    local gf_setup_calls = 0
    package.loaded["rails-tools.core.gf"] = {
      setup = function()
        gf_setup_calls = gf_setup_calls + 1
        error("forced gf failure")
      end,
    }
    local rails_tools = require("rails-tools")
    assert.has.errors(function()
      rails_tools.setup()
    end)

    package.loaded["rails-tools.core.gf"] = {
      setup = function()
        gf_setup_calls = gf_setup_calls + 1
      end,
    }
    assert.has_no.errors(function()
      rails_tools.setup()
    end)

    assert.are.equal(2, gf_setup_calls)
    assert.are.equal(1, #vim.api.nvim_get_autocmds({ group = "rails_tools_schema_cache" }))
    assert.are.equal(1, #vim.api.nvim_get_autocmds({ group = "rails_tools_lsp_schema" }))
  end)

  it("setup() is a no-op after a successful run", function()
    local gf_setup_calls = 0
    package.loaded["rails-tools.core.gf"] = {
      setup = function()
        gf_setup_calls = gf_setup_calls + 1
      end,
    }
    local rails_tools = require("rails-tools")
    rails_tools.setup()
    rails_tools.setup()
    assert.are.equal(1, gf_setup_calls)
  end)

  describe("modules.schema", function()
    local registered_sources

    before_each(function()
      pcall(vim.api.nvim_del_augroup_by_name, "rails_tools_schema_cache")
      pcall(vim.api.nvim_del_augroup_by_name, "rails_tools_lsp_schema")
      registered_sources = {}
      package.loaded["cmp"] = {
        register_source = function(name)
          table.insert(registered_sources, name)
        end,
      }
    end)

    after_each(function()
      package.loaded["cmp"] = nil
    end)

    it("skips the schema cache, LSP override and cmp source when modules.schema is false", function()
      require("rails-tools").setup({ modules = { schema = false } })

      assert.are.equal(0, vim.fn.exists("#rails_tools_schema_cache"))
      assert.are.equal(0, vim.fn.exists("#rails_tools_lsp_schema"))
      assert.are.same({}, registered_sources)
    end)

    it("sets up the schema cache, LSP override and cmp source by default", function()
      require("rails-tools").setup()

      assert.are.equal(1, vim.fn.exists("#rails_tools_schema_cache"))
      assert.are.equal(1, vim.fn.exists("#rails_tools_lsp_schema"))
      assert.are.same({ "rails_schema" }, registered_sources)
    end)
  end)
end)
