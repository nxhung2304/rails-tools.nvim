local config = require("rails-tools.config")

describe("integrations.cmp", function()
  local cmp_module
  local bufnr
  local dummy_client_ids

  local function get_clients()
    return (vim.lsp.get_clients or vim.lsp.get_active_clients)({ bufnr = bufnr })
  end

  local function fake_server_cmd()
    return function(dispatchers)
      local closing = false
      return {
        request = function(method, _, callback)
          if method == "initialize" then
            callback(nil, { capabilities = {} })
          elseif method == "shutdown" then
            callback(nil, nil)
          end
          return true, 1
        end,
        notify = function(method)
          if method == "exit" then
            closing = true
            dispatchers.on_exit(0, 15)
          end
          return true
        end,
        is_closing = function()
          return closing
        end,
        terminate = function()
          closing = true
          dispatchers.on_exit(0, 15)
        end,
      }
    end
  end

  local function attach_dummy_client(name)
    local id = vim.lsp.start({ name = name, cmd = fake_server_cmd(), root_dir = vim.fn.getcwd() }, { bufnr = bufnr })
    table.insert(dummy_client_ids, id)
    local attached = vim.wait(1000, function()
      for _, client in ipairs(get_clients()) do
        if client.name == name then
          return true
        end
      end
      return false
    end)
    assert.is_true(attached, "dummy LSP client " .. name .. " did not attach")
  end

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
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    dummy_client_ids = {}
  end)

  after_each(function()
    for _, id in ipairs(dummy_client_ids) do
      vim.lsp.stop_client(id, true)
    end
    local detached = vim.wait(1000, function()
      return #get_clients() == 0
    end)
    assert.is_true(detached, "dummy LSP client did not detach")
    vim.api.nvim_buf_delete(bufnr, { force = true })
    config.setup({})
    package.loaded["cmp"] = nil
    package.loaded["rails-tools.core.schema"] = nil
    package.loaded["rails-tools.integrations.cmp"] = nil
  end)

  local function complete(cursor_before_line)
    local source = cmp_module._source.new()
    local result
    source:complete({ context = { cursor_before_line = cursor_before_line, bufnr = bufnr } }, function(r)
      result = r
    end)
    return result
  end

  it("suggests known columns when no dedupe_with_lsp is configured", function()
    config.setup({})

    local result = complete("user.")

    assert.equals(1, #result.items)
    assert.equals("email", result.items[1].label)
  end)

  it("suppresses columns when a configured LSP client is attached to the buffer", function()
    config.setup({ cmp = { dedupe_with_lsp = { "ruby_lsp" } } })
    attach_dummy_client("ruby_lsp")

    local result = complete("user.")

    assert.equals(0, #result.items)
  end)

  it("still suggests columns when the configured LSP client isn't attached", function()
    config.setup({ cmp = { dedupe_with_lsp = { "ruby_lsp" } } })

    local result = complete("user.")

    assert.equals(1, #result.items)
    assert.equals("email", result.items[1].label)
  end)

  it("suppresses columns when any of several configured clients is attached", function()
    config.setup({ cmp = { dedupe_with_lsp = { "solargraph", "ruby_lsp" } } })
    attach_dummy_client("ruby_lsp")

    local result = complete("user.")

    assert.equals(0, #result.items)
  end)

  it("still suggests columns when only an unlisted LSP client is attached", function()
    config.setup({ cmp = { dedupe_with_lsp = { "ruby_lsp" } } })
    attach_dummy_client("solargraph")

    local result = complete("user.")

    assert.equals(1, #result.items)
  end)

  it("suggests columns after a safe navigation receiver", function()
    config.setup({})

    local result = complete("user&.")

    assert.equals(1, #result.items)
    assert.equals("email", result.items[1].label)
  end)
end)
