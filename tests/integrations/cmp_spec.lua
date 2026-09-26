local config = require("rails-tools.config")

describe("integrations.cmp", function()
  local cmp_module
  local original_get_clients

  before_each(function()
    package.loaded["cmp"] = {
      lsp = { CompletionItemKind = { Field = 5 } },
      register_source = function() end,
    }
    package.loaded["rails-tools.integrations.cmp"] = nil
    package.loaded["rails-tools.core.schema"] = {
      resolve = function()
        return {
          known_models = { User = true },
          models = {
            User = {
              columns = {
                email = { signature = ':string, null: false', location = { file = "x", lnum = 1, col = 0 } },
              },
            },
          },
        }
      end,
    }
    cmp_module = require("rails-tools.integrations.cmp")
    original_get_clients = vim.lsp.get_clients
  end)

  after_each(function()
    vim.lsp.get_clients = original_get_clients
    config.setup({})
    package.loaded["cmp"] = nil
    package.loaded["rails-tools.core.schema"] = nil
    package.loaded["rails-tools.integrations.cmp"] = nil
  end)

  local function complete(cursor_before_line)
    local source = cmp_module._source.new()
    local result
    source:complete({ context = { cursor_before_line = cursor_before_line, bufnr = 1 } }, function(r)
      result = r
    end)
    return result
  end

  it("suggests known columns when no dedupe_with_lsp is configured", function()
    config.setup({})
    vim.lsp.get_clients = function()
      return {}
    end

    local result = complete("user.")

    assert.equals(1, #result.items)
    assert.equals("email", result.items[1].label)
  end)

  it("suppresses columns when a configured LSP client is attached to the buffer", function()
    config.setup({ cmp = { dedupe_with_lsp = { "ruby_lsp" } } })
    vim.lsp.get_clients = function(opts)
      if vim.tbl_contains(opts.name, "ruby_lsp") then
        return { { name = "ruby_lsp" } }
      end
      return {}
    end

    local result = complete("user.")

    assert.equals(0, #result.items)
  end)

  it("still suggests columns when the configured LSP client isn't attached", function()
    config.setup({ cmp = { dedupe_with_lsp = { "ruby_lsp" } } })
    vim.lsp.get_clients = function()
      return {}
    end

    local result = complete("user.")

    assert.equals(1, #result.items)
    assert.equals("email", result.items[1].label)
  end)
end)
