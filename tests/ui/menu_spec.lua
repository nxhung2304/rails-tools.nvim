local STUBBED_MODULES = {
  "rails-tools.core.alternate",
  "rails-tools.core.finder",
  "rails-tools.core.routes",
  "rails-tools.core.console",
  "rails-tools.core.runner",
  "rails-tools.integrations.rspec",
  "rails-tools.core.generators",
  "rails-tools.integrations.grape",
}

local ACTION_WAIT_MS = 100

describe("rails-tools.ui.menu", function()
  local menu
  local calls
  local orig_select
  local select_items
  local select_opts
  local pick_label

  local function stub_modules()
    package.preload["rails-tools.core.alternate"] = function()
      return { open = function() table.insert(calls, { "alternate.open" }) end }
    end
    package.preload["rails-tools.core.finder"] = function()
      return { find = function(resource_type) table.insert(calls, { "finder.find", resource_type }) end }
    end
    package.preload["rails-tools.core.routes"] = function()
      return { show = function() table.insert(calls, { "routes.show" }) end }
    end
    package.preload["rails-tools.core.console"] = function()
      return { open = function() table.insert(calls, { "console.open" }) end }
    end
    package.preload["rails-tools.core.runner"] = function()
      return { run_prompt = function() table.insert(calls, { "runner.run_prompt" }) end }
    end
    package.preload["rails-tools.integrations.rspec"] = function()
      return {
        run_nearest = function() table.insert(calls, { "rspec.run_nearest" }) end,
        run_file = function() table.insert(calls, { "rspec.run_file" }) end,
      }
    end
    package.preload["rails-tools.core.generators"] = function()
      return { run_prompt = function() table.insert(calls, { "generators.run_prompt" }) end }
    end
    package.preload["rails-tools.integrations.grape"] = function()
      return { show = function() table.insert(calls, { "grape.show" }) end }
    end
  end

  local function open_menu_and_wait()
    menu.open()
    vim.wait(ACTION_WAIT_MS, function()
      return #calls > 0
    end)
  end

  local function labels()
    return vim.tbl_map(function(item)
      return select_opts.format_item(item)
    end, select_items)
  end

  before_each(function()
    calls = {}
    pick_label = nil
    select_items = nil
    select_opts = nil
    for _, name in ipairs(STUBBED_MODULES) do
      package.loaded[name] = nil
    end
    package.loaded["rails-tools.ui.menu"] = nil
    package.loaded["rails-tools.config"] = nil
    stub_modules()

    orig_select = vim.ui.select
    vim.ui.select = function(items, opts, on_choice)
      select_items = items
      select_opts = opts
      local choice
      for _, item in ipairs(items) do
        if opts.format_item(item) == pick_label then
          choice = item
        end
      end
      on_choice(choice)
    end

    menu = require("rails-tools.ui.menu")
  end)

  after_each(function()
    vim.ui.select = orig_select
    for _, name in ipairs(STUBBED_MODULES) do
      package.preload[name] = nil
      package.loaded[name] = nil
    end
    package.loaded["rails-tools.ui.menu"] = nil
    package.loaded["rails-tools.config"] = nil
  end)

  it("opens a menu titled Rails Tools", function()
    menu.open()

    assert.are.equal("Rails Tools", select_opts.prompt)
  end)

  it("lists the Phase 1 actions in order", function()
    menu.open()

    assert.are.same({ "Alternate File", "Find Resource", "View Routes", "Open Console", "Run Code" }, labels())
  end)

  it("opens the alternate file when Alternate File is chosen", function()
    pick_label = "Alternate File"

    open_menu_and_wait()

    assert.are.same({ { "alternate.open" } }, calls)
  end)

  it("finds every resource when Find Resource is chosen", function()
    pick_label = "Find Resource"

    open_menu_and_wait()

    assert.are.same({ { "finder.find", "all" } }, calls)
  end)

  it("shows the routes when View Routes is chosen", function()
    pick_label = "View Routes"

    open_menu_and_wait()

    assert.are.same({ { "routes.show" } }, calls)
  end)

  it("opens the console when Open Console is chosen", function()
    pick_label = "Open Console"

    open_menu_and_wait()

    assert.are.same({ { "console.open" } }, calls)
  end)

  it("prompts for code when Run Code is chosen", function()
    pick_label = "Run Code"

    open_menu_and_wait()

    assert.are.same({ { "runner.run_prompt" } }, calls)
  end)

  describe("with modules.rspec = true", function()
    before_each(function()
      require("rails-tools.config").setup({ modules = { rspec = true } })
    end)

    it("adds the spec actions after the Phase 1 actions", function()
      menu.open()

      assert.are.same({
        "Alternate File",
        "Find Resource",
        "View Routes",
        "Open Console",
        "Run Code",
        "Run Nearest Spec",
        "Run Spec File",
      }, labels())
    end)

    it("runs the nearest spec when Run Nearest Spec is chosen", function()
      pick_label = "Run Nearest Spec"

      open_menu_and_wait()

      assert.are.same({ { "rspec.run_nearest" } }, calls)
    end)

    it("runs the spec file when Run Spec File is chosen", function()
      pick_label = "Run Spec File"

      open_menu_and_wait()

      assert.are.same({ { "rspec.run_file" } }, calls)
    end)
  end)

  describe("with modules.generators = true", function()
    before_each(function()
      require("rails-tools.config").setup({ modules = { generators = true } })
    end)

    it("adds Run Generator after the Phase 1 actions", function()
      menu.open()

      assert.are.same(
        { "Alternate File", "Find Resource", "View Routes", "Open Console", "Run Code", "Run Generator" },
        labels()
      )
    end)

    it("prompts for a generator when Run Generator is chosen", function()
      pick_label = "Run Generator"

      open_menu_and_wait()

      assert.are.same({ { "generators.run_prompt" } }, calls)
    end)
  end)

  describe("with modules.grape = true", function()
    before_each(function()
      require("rails-tools.config").setup({ modules = { grape = true } })
    end)

    it("adds Grape Endpoints after the Phase 1 actions", function()
      menu.open()

      assert.are.same(
        { "Alternate File", "Find Resource", "View Routes", "Open Console", "Run Code", "Grape Endpoints" },
        labels()
      )
    end)

    it("shows the Grape endpoints when Grape Endpoints is chosen", function()
      pick_label = "Grape Endpoints"

      open_menu_and_wait()

      assert.are.same({ { "grape.show" } }, calls)
    end)
  end)

  it("does nothing when the menu is cancelled", function()
    open_menu_and_wait()

    assert.are.same({}, calls)
  end)
end)
