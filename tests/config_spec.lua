describe("rails-tools.config", function()
  local config

  before_each(function()
    package.loaded["rails-tools.config"] = nil
    config = require("rails-tools.config")
  end)

  it("setup() with nil returns defaults", function()
    local res = config.setup(nil)
    assert.are.same(config.defaults, res)
  end)

  it("get() before any setup() returns defaults", function()
    local current = config.get()
    assert.are.same(config.defaults, current)
  end)

  it("setup() return value equals what get() returns afterwards", function()
    local setup_res = config.setup({ keymaps = { prefix = "<leader>x" } })
    local get_res = config.get()
    assert.are.same(setup_res, get_res)
  end)

  it("partial override keeps sibling keys intact", function()
    config.setup({ keymaps = { prefix = "<leader>x" } })
    local current = config.get()
    assert.are.equal("<leader>x", current.keymaps.prefix)
    assert.are.equal(true, current.keymaps.enabled)
  end)

  it("module toggle overrides specific modules while keeping others", function()
    config.setup({ modules = { rspec = true } })
    local current = config.get()
    assert.are.equal(true, current.modules.rspec)
    assert.are.equal(true, current.modules.schema)
    assert.are.equal(false, current.modules.generators)
  end)

  it("terminal override updates specified options and preserves others", function()
    config.setup({ terminal = { direction = "horizontal", horizontal = { size = 20 } } })
    local current = config.get()
    assert.are.equal("horizontal", current.terminal.direction)
    assert.are.equal(20, current.terminal.horizontal.size)
    assert.are.equal("auto", current.terminal.provider)
    assert.are.equal(0.8, current.terminal.float.width)
  end)

  it("finder override updates specified options while leaving other resources unchanged", function()
    config.setup({
      finder = {
        cache_ttl = 60,
        resources = {
          models = { paths = { "custom/models" } },
        },
      },
    })
    local current = config.get()
    assert.are.equal(60, current.finder.cache_ttl)
    assert.are.same({ "custom/models" }, current.finder.resources.models.paths)
    assert.are.same({ "app/controllers" }, current.finder.resources.controllers.paths)
  end)

  it("routes override updates options while preserving defaults", function()
    config.setup({ routes = { cache_ttl = 60 } })
    local current = config.get()
    assert.are.equal(60, current.routes.cache_ttl)
    assert.are.equal("bin/rails routes", current.routes.command)
  end)

  it("defaults contain every top-level key", function()
    local expected_keys = {
      "modules",
      "terminal",
      "finder",
      "routes",
      "console",
      "runner",
      "keymaps",
      "alternate",
      "view",
      "rspec",
      "cmp",
    }
    for _, key in ipairs(expected_keys) do
      assert.is_not_nil(config.defaults[key])
    end
  end)

  it("setup() does not mutate defaults", function()
    config.setup({ keymaps = { prefix = "<leader>x" } })
    assert.are.equal("<leader>r", config.defaults.keymaps.prefix)
  end)

  it("custom alternate mappings prepends custom mappings to built-in mappings", function()
    config.setup({ alternate = { custom_mappings = { { from = "^a$", to = "b" } } } })
    local mappings = config.alternate_mappings("rspec")
    assert.are.equal("^a$", mappings[1].from)
    assert.are.equal("b", mappings[1].to)
    assert.is_true(#mappings > 1)
  end)

  it("alternate_mappings accepts pattern and target aliases", function()
    config.setup({ alternate = { custom_mappings = { { pattern = "^a$", target = "b" } } } })
    local mappings = config.alternate_mappings("rspec")
    assert.are.equal("^a$", mappings[1].from)
    assert.are.equal("b", mappings[1].to)
  end)
end)