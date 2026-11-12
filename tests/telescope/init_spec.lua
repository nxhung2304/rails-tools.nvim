local MODULES_TO_RELOAD = {
  "rails-tools.telescope",
  "rails-tools.config",
  "rails-tools.core.finder",
  "telescope",
  "telescope._extensions.rails",
}

describe("rails-tools.telescope", function()
  local find_calls
  local notifications
  local orig_notify

  local function reload_modules()
    for _, name in ipairs(MODULES_TO_RELOAD) do
      package.loaded[name] = nil
      package.preload[name] = nil
    end
  end

  before_each(function()
    reload_modules()
    find_calls = {}
    package.loaded["rails-tools.core.finder"] = {
      find = function(resource_type, opts)
        table.insert(find_calls, { resource_type = resource_type, opts = opts })
      end,
    }

    notifications = {}
    orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end
  end)

  after_each(function()
    vim.notify = orig_notify
    reload_modules()
  end)

  describe("exports", function()
    local default_resource_types = {
      "models",
      "controllers",
      "views",
      "services",
      "policies",
      "jobs",
      "mailers",
      "serializers",
      "specs",
      "factories",
    }

    for _, resource_type in ipairs(default_resource_types) do
      it(resource_type .. " opens the finder with Telescope and the picker options", function()
        local rails_telescope = require("rails-tools.telescope")
        local picker_opts = { layout_strategy = "vertical" }

        rails_telescope.exports[resource_type](picker_opts)

        assert.are.same({
          { resource_type = resource_type, opts = { provider = "telescope", picker_opts = picker_opts } },
        }, find_calls)
      end)
    end

    it("grape shows a not-available message without opening the finder", function()
      local rails_telescope = require("rails-tools.telescope")

      rails_telescope.exports.grape({})

      assert.are.equal(0, #find_calls)
      assert.are.same({
        { msg = "Rails: Grape routes picker is not available yet", level = vim.log.levels.INFO },
      }, notifications)
    end)

    it("rails opens the finder for every resource", function()
      require("rails-tools.telescope").exports.rails({})

      assert.are.same({ { resource_type = "all", opts = { provider = "telescope", picker_opts = {} } } }, find_calls)
    end)

    it("exports custom resources and skips disabled ones", function()
      require("rails-tools.config").setup({
        finder = { resources = { interactors = { paths = { "app/interactors" } }, jobs = false } },
      })

      local exports = require("rails-tools.telescope").exports

      assert.is_function(exports.interactors)
      assert.is_nil(exports.jobs)
    end)

    it("does not export a routes picker", function()
      assert.is_nil(require("rails-tools.telescope").exports.routes)
    end)
  end)

  describe("setup", function()
    it("returns false without error when telescope.nvim is missing", function()
      local loaded
      assert.has_no.errors(function()
        loaded = require("rails-tools.telescope").setup()
      end)
      assert.is_false(loaded)
    end)

    it("does not load telescope.nvim when it is installed but not loaded yet", function()
      package.preload["telescope"] = function()
        return { load_extension = function() end }
      end

      local loaded = require("rails-tools.telescope").setup()

      assert.is_false(loaded)
      assert.is_nil(package.loaded["telescope"])
    end)

    it("loads the rails extension when telescope.nvim is already loaded", function()
      local loaded_extensions = {}
      package.loaded["telescope"] = {
        load_extension = function(name)
          table.insert(loaded_extensions, name)
        end,
      }

      local loaded = require("rails-tools.telescope").setup()

      assert.is_true(loaded)
      assert.are.same({ "rails" }, loaded_extensions)
    end)

    it("warns and returns false when loading the extension fails", function()
      package.loaded["telescope"] = {
        load_extension = function()
          error("boom")
        end,
      }

      assert.is_false(require("rails-tools.telescope").setup())
      assert.are.equal(1, #notifications)
      assert.matches("^Rails: could not load Telescope extension: .*boom", notifications[1].msg)
      assert.are.equal(vim.log.levels.WARN, notifications[1].level)
    end)
  end)

  describe("telescope._extensions.rails", function()
    it("registers the rails-tools exports", function()
      local registered
      package.preload["telescope"] = function()
        return {
          register_extension = function(extension)
            registered = extension
            return extension
          end,
        }
      end

      local extension = require("telescope._extensions.rails")

      assert.are.equal(require("rails-tools.telescope").exports, registered.exports)
      assert.are.equal(registered, extension)
    end)
  end)
end)
