local STUBBED_MODULES = {
  "rails-tools.ui.menu",
  "rails-tools.core.alternate",
  "rails-tools.core.finder",
  "rails-tools.core.console",
  "rails-tools.core.runner",
}

local TEST_LEADER = ","
local DEFAULT_KEYS = { ",rr", ",ra", ",rf", ",rc", ",rx" }
local CUSTOM_PREFIX_KEYS = { ",xr", ",xa", ",xf", ",xc", ",xx" }

describe("rails-tools.keymaps", function()
  local keymaps
  local config
  local calls
  local orig_mapleader

  local function stub_modules()
    package.preload["rails-tools.ui.menu"] = function()
      return { open = function() table.insert(calls, { "menu.open" }) end }
    end
    package.preload["rails-tools.core.alternate"] = function()
      return { open = function() table.insert(calls, { "alternate.open" }) end }
    end
    package.preload["rails-tools.core.finder"] = function()
      return { find = function(resource_type) table.insert(calls, { "finder.find", resource_type }) end }
    end
    package.preload["rails-tools.core.console"] = function()
      return { open = function() table.insert(calls, { "console.open" }) end }
    end
    package.preload["rails-tools.core.runner"] = function()
      return { run_prompt = function() table.insert(calls, { "runner.run_prompt" }) end }
    end
  end

  local function delete_test_keymaps()
    for _, lhs in ipairs(vim.list_extend(vim.deepcopy(DEFAULT_KEYS), CUSTOM_PREFIX_KEYS)) do
      pcall(vim.keymap.del, "n", lhs)
    end
  end

  local function normal_mapping(lhs)
    return vim.fn.maparg(lhs, "n", false, true)
  end

  local function run_mapping(lhs)
    normal_mapping(lhs).callback()
  end

  before_each(function()
    calls = {}
    orig_mapleader = vim.g.mapleader
    vim.g.mapleader = TEST_LEADER
    delete_test_keymaps()
    for _, name in ipairs(STUBBED_MODULES) do
      package.loaded[name] = nil
    end
    package.loaded["rails-tools.keymaps"] = nil
    package.loaded["rails-tools.config"] = nil
    stub_modules()

    config = require("rails-tools.config")
    keymaps = require("rails-tools.keymaps")
  end)

  after_each(function()
    delete_test_keymaps()
    vim.g.mapleader = orig_mapleader
    for _, name in ipairs(STUBBED_MODULES) do
      package.preload[name] = nil
      package.loaded[name] = nil
    end
    package.loaded["rails-tools.keymaps"] = nil
    package.loaded["rails-tools.config"] = nil
  end)

  it("registers the default keymaps under <leader>r", function()
    config.setup()

    keymaps.setup()

    for _, lhs in ipairs(DEFAULT_KEYS) do
      assert.is_not_nil(normal_mapping(lhs).callback, lhs .. " is not mapped")
    end
  end)

  it("registers keymaps as silent and non-recursive with a description", function()
    config.setup()

    keymaps.setup()

    for _, lhs in ipairs(DEFAULT_KEYS) do
      local mapping = normal_mapping(lhs)
      assert.are.equal(1, mapping.silent, lhs .. " is not silent")
      assert.are.equal(1, mapping.noremap, lhs .. " is recursive")
      assert.is_truthy(mapping.desc and mapping.desc ~= "", lhs .. " has no description")
    end
  end)

  it("opens the Rails menu with <leader>rr", function()
    config.setup()
    keymaps.setup()

    run_mapping(",rr")

    assert.are.same({ { "menu.open" } }, calls)
  end)

  it("opens the alternate file with <leader>ra", function()
    config.setup()
    keymaps.setup()

    run_mapping(",ra")

    assert.are.same({ { "alternate.open" } }, calls)
  end)

  it("finds every resource with <leader>rf", function()
    config.setup()
    keymaps.setup()

    run_mapping(",rf")

    assert.are.same({ { "finder.find", "all" } }, calls)
  end)

  it("opens the console with <leader>rc", function()
    config.setup()
    keymaps.setup()

    run_mapping(",rc")

    assert.are.same({ { "console.open" } }, calls)
  end)

  it("prompts for runner code with <leader>rx", function()
    config.setup()
    keymaps.setup()

    run_mapping(",rx")

    assert.are.same({ { "runner.run_prompt" } }, calls)
  end)

  it("uses the prefix from config", function()
    config.setup({ keymaps = { prefix = "<leader>x" } })

    keymaps.setup()

    for _, lhs in ipairs(CUSTOM_PREFIX_KEYS) do
      assert.is_not_nil(normal_mapping(lhs).callback, lhs .. " is not mapped")
    end
    for _, lhs in ipairs(DEFAULT_KEYS) do
      assert.are.same({}, normal_mapping(lhs), lhs .. " should not be mapped")
    end
  end)

  it("registers nothing when keymaps are disabled", function()
    config.setup({ keymaps = { enabled = false } })

    keymaps.setup()

    for _, lhs in ipairs(DEFAULT_KEYS) do
      assert.are.same({}, normal_mapping(lhs), lhs .. " should not be mapped")
    end
  end)
end)
