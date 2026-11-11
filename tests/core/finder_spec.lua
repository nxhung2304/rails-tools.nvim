local finder
local config

local MODULES_TO_RELOAD = {
  "rails-tools.core.finder",
  "rails-tools.config",
  "rails-tools.detectors.rails",
  "rails-tools.cache",
}

local TELESCOPE_MODULES = {
  "telescope",
  "telescope.pickers",
  "telescope.finders",
  "telescope.config",
  "telescope.actions",
  "telescope.actions.state",
}

describe("rails-tools.core.finder", function()
  local tmp_dir
  local orig_cwd
  local orig_notify
  local orig_select
  local notifications
  local select_calls
  local select_choice

  local function reload_modules()
    for _, name in ipairs(MODULES_TO_RELOAD) do
      package.loaded[name] = nil
    end
  end

  local function remove_fake_telescope()
    for _, name in ipairs(TELESCOPE_MODULES) do
      package.loaded[name] = nil
      package.preload[name] = nil
    end
  end

  local function create_rails_project(dir)
    vim.fn.writefile({}, dir .. "/Gemfile")
    vim.fn.mkdir(dir .. "/bin", "p")
    vim.fn.writefile({}, dir .. "/bin/rails")
  end

  local function create_file(relative_path)
    local path = tmp_dir .. "/" .. relative_path
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({}, path)
  end

  local function listed_items()
    assert.are.equal(1, #select_calls)
    return select_calls[1].items
  end

  before_each(function()
    orig_cwd = vim.fn.getcwd()
    tmp_dir = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(tmp_dir, "p")
    reload_modules()
    remove_fake_telescope()

    notifications = {}
    orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    select_calls = {}
    select_choice = nil
    orig_select = vim.ui.select
    vim.ui.select = function(items, opts, on_choice)
      table.insert(select_calls, { items = items, opts = opts })
      on_choice(select_choice)
    end

    config = require("rails-tools.config")
    config.setup({ finder = { provider = "native" } })
    finder = require("rails-tools.core.finder")

    create_rails_project(tmp_dir)
    vim.cmd("enew!")
    vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.ui.select = orig_select
    remove_fake_telescope()
    vim.cmd("silent! %bwipeout!")
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_dir, "rf")
    reload_modules()
  end)

  describe("resource types", function()
    local cases = {
      { "models", "app/models/user.rb" },
      { "controllers", "app/controllers/users_controller.rb" },
      { "views", "app/views/users/index.html.erb" },
      { "services", "app/services/create_user.rb" },
      { "policies", "app/policies/user_policy.rb" },
      { "jobs", "app/jobs/sync_job.rb" },
      { "mailers", "app/mailers/user_mailer.rb" },
      { "serializers", "app/serializers/user_serializer.rb" },
      { "specs", "spec/models/user_spec.rb" },
      { "factories", "spec/factories/users.rb" },
    }

    for _, case in ipairs(cases) do
      local resource_type, file = case[1], case[2]

      it("lists " .. resource_type .. " sorted", function()
        local first_file = vim.fn.fnamemodify(file, ":h") .. "/a_first.rb"
        create_file(file)
        create_file(first_file)
        create_file("lib/tasks/other.rake")

        finder.find(resource_type)

        assert.are.same({ first_file, file }, listed_items())
      end)
    end

    it("lists nested files sorted, root-relative", function()
      create_file("app/models/user.rb")
      create_file("app/models/admin/account.rb")
      create_file("app/models/concerns/trackable.rb")

      finder.find("models")

      assert.are.same({
        "app/models/admin/account.rb",
        "app/models/concerns/trackable.rb",
        "app/models/user.rb",
      }, listed_items())
    end)

    it("skips hidden files and hidden directories", function()
      create_file("app/models/user.rb")
      create_file("app/models/concerns/.keep")
      create_file("app/models/.hidden/secret.rb")

      finder.find("models")

      assert.are.same({ "app/models/user.rb" }, listed_items())
    end)

    it("lists files from every custom path of a type", function()
      config.setup({
        finder = {
          provider = "native",
          resources = { services = { paths = { "app/services", "app/interactors" } } },
        },
      })
      create_file("app/services/create_user.rb")
      create_file("app/interactors/sign_up.rb")

      finder.find("services")

      assert.are.same({ "app/interactors/sign_up.rb", "app/services/create_user.rb" }, listed_items())
    end)

    it("skips configured paths that do not exist", function()
      create_file("spec/models/user_spec.rb")

      finder.find("specs")

      assert.are.same({ "spec/models/user_spec.rb" }, listed_items())
    end)

    it("ignores resources without paths when listing 'all'", function()
      config.setup({
        finder = {
          provider = "native",
          resources = { jobs = false, widgets = {} },
        },
      })
      create_file("app/models/user.rb")

      finder.find("all")

      assert.are.same({ "app/models/user.rb" }, listed_items())
    end)

    it("lists every resource file once for 'all'", function()
      create_file("app/models/user.rb")
      create_file("app/controllers/users_controller.rb")
      create_file("spec/factories/users.rb")
      create_file("lib/tasks/other.rake")

      finder.find("all")

      assert.are.same({
        "app/controllers/users_controller.rb",
        "app/models/user.rb",
        "spec/factories/users.rb",
      }, listed_items())
    end)
  end)

  describe("opening", function()
    it("opens the selected file in the current buffer", function()
      create_file("app/models/user.rb")
      select_choice = "app/models/user.rb"

      finder.find("models")

      assert.are.equal(tmp_dir .. "/app/models/user.rb", vim.api.nvim_buf_get_name(0))
      assert.are.equal("Rails models: ", select_calls[1].opts.prompt)
    end)

    it("opens nothing when the selection is cancelled", function()
      create_file("app/models/user.rb")
      local bufnr = vim.api.nvim_get_current_buf()

      finder.find("models")

      assert.are.equal(bufnr, vim.api.nvim_get_current_buf())
      assert.are.equal("", vim.api.nvim_buf_get_name(0))
    end)

    it("shows an error instead of raising when the file cannot be opened", function()
      create_file("app/models/user.rb")
      vim.o.hidden = false
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
      select_choice = "app/models/user.rb"

      finder.find("models")

      vim.o.hidden = true
      vim.bo.modified = false
      assert.are.equal(vim.log.levels.ERROR, notifications[1].level)
      assert.is_truthy(notifications[1].msg:find("E37", 1, true))
    end)

    it("uses the project of the current file when cwd is another project", function()
      local other_dir = vim.fn.resolve(vim.fn.tempname())
      vim.fn.mkdir(other_dir, "p")
      create_rails_project(other_dir)
      vim.fn.mkdir(other_dir .. "/app/models", "p")
      vim.fn.writefile({}, other_dir .. "/app/models/order.rb")
      create_file("app/models/user.rb")
      vim.cmd("edit " .. vim.fn.fnameescape(other_dir .. "/app/models/order.rb"))

      finder.find("models")

      assert.are.same({ "app/models/order.rb" }, listed_items())
      vim.fn.delete(other_dir, "rf")
    end)
  end)

  describe("warnings", function()
    it("warns for an unknown resource type", function()
      finder.find("widgets")

      assert.are.equal(0, #select_calls)
      assert.are.same({ msg = "Rails: unknown resource type 'widgets'", level = vim.log.levels.WARN }, notifications[1])
    end)

    it("warns for a resource type turned off or without paths", function()
      config.setup({
        finder = {
          provider = "native",
          resources = { jobs = false, widgets = {} },
        },
      })

      finder.find("jobs")
      finder.find("widgets")

      assert.are.equal(0, #select_calls)
      assert.are.same({
        { msg = "Rails: unknown resource type 'jobs'", level = vim.log.levels.WARN },
        { msg = "Rails: unknown resource type 'widgets'", level = vim.log.levels.WARN },
      }, notifications)
    end)

    it("warns about the project before the resource type outside a Rails project", function()
      vim.fn.delete(tmp_dir .. "/Gemfile")

      finder.find("widgets")

      assert.are.same({ { msg = "Rails: not a Rails project", level = vim.log.levels.WARN } }, notifications)
    end)

    it("warns when no resource type is given", function()
      finder.find("")

      assert.are.equal(0, #select_calls)
      assert.are.same({ msg = "Rails: missing resource type", level = vim.log.levels.WARN }, notifications[1])
    end)

    it("warns outside a Rails project", function()
      vim.fn.delete(tmp_dir .. "/Gemfile")

      finder.find("models")

      assert.are.equal(0, #select_calls)
      assert.are.same({ msg = "Rails: not a Rails project", level = vim.log.levels.WARN }, notifications[1])
    end)

    it("informs and opens no picker when there are no files", function()
      finder.find("models")

      assert.are.equal(0, #select_calls)
      assert.are.same({ msg = "Rails: no models found", level = vim.log.levels.INFO }, notifications[1])
    end)
  end)

  describe("cache", function()
    it("reuses the list within the TTL", function()
      create_file("app/models/user.rb")
      finder.find("models")
      create_file("app/models/order.rb")

      finder.find("models")

      assert.are.same({ "app/models/user.rb" }, select_calls[2].items)
    end)

    it("rescans after the TTL expires", function()
      config.setup({ finder = { provider = "native", cache_ttl = 0 } })
      create_file("app/models/user.rb")
      finder.find("models")
      create_file("app/models/order.rb")

      finder.find("models")

      assert.are.same({ "app/models/order.rb", "app/models/user.rb" }, select_calls[2].items)
    end)

    it("rescans when the configured paths change", function()
      create_file("app/services/create_user.rb")
      create_file("app/interactors/sign_up.rb")
      finder.find("services")
      config.setup({
        finder = {
          provider = "native",
          resources = { services = { paths = { "app/interactors" } } },
        },
      })

      finder.find("services")

      assert.are.same({ "app/interactors/sign_up.rb" }, select_calls[2].items)
    end)
  end)

  describe("telescope", function()
    local picker_specs
    local select_default_handler
    local closed_prompts

    local function install_fake_telescope(selected_entry)
      picker_specs = {}
      closed_prompts = {}
      select_default_handler = nil
      package.preload["telescope"] = function()
        return {}
      end
      package.preload["telescope.pickers"] = function()
        return {
          new = function(_, spec)
            table.insert(picker_specs, spec)
            return {
              find = function()
                spec.attach_mappings(42, function() end)
              end,
            }
          end,
        }
      end
      package.preload["telescope.finders"] = function()
        return {
          new_table = function(opts)
            return opts
          end,
        }
      end
      package.preload["telescope.config"] = function()
        return {
          values = {
            generic_sorter = function()
              return "sorter"
            end,
            file_previewer = function()
              return "previewer"
            end,
          },
        }
      end
      package.preload["telescope.actions"] = function()
        return {
          select_default = {
            replace = function(_, handler)
              select_default_handler = handler
            end,
          },
          close = function(prompt_bufnr)
            table.insert(closed_prompts, prompt_bufnr)
          end,
        }
      end
      package.preload["telescope.actions.state"] = function()
        return {
          get_selected_entry = function()
            return selected_entry
          end,
        }
      end
    end

    it("uses Telescope in auto mode and opens the selected file", function()
      config.setup({ finder = { provider = "auto" } })
      create_file("app/models/user.rb")
      install_fake_telescope({ value = "app/models/user.rb", path = tmp_dir .. "/app/models/user.rb" })

      finder.find("models")
      select_default_handler()

      local spec = picker_specs[1]
      assert.are.equal(0, #select_calls)
      assert.are.equal("Rails models", spec.prompt_title)
      assert.are.equal("previewer", spec.previewer)
      assert.are.same({ 42 }, closed_prompts)
      assert.are.equal(tmp_dir .. "/app/models/user.rb", vim.api.nvim_buf_get_name(0))
    end)

    it("gives Telescope entries an absolute path for the preview", function()
      config.setup({ finder = { provider = "auto" } })
      create_file("app/models/user.rb")
      install_fake_telescope(nil)

      finder.find("models")

      local entry = picker_specs[1].finder.entry_maker("app/models/user.rb")
      assert.are.same({
        value = "app/models/user.rb",
        display = "app/models/user.rb",
        ordinal = "app/models/user.rb",
        path = tmp_dir .. "/app/models/user.rb",
      }, entry)
    end)

    it("uses vim.ui.select in native mode even when Telescope is installed", function()
      create_file("app/models/user.rb")
      install_fake_telescope(nil)

      finder.find("models")

      assert.are.equal(0, #picker_specs)
      assert.are.equal(1, #select_calls)
    end)

    it("falls back to vim.ui.select when Telescope is requested but missing", function()
      config.setup({ finder = { provider = "telescope" } })
      create_file("app/models/user.rb")

      finder.find("models")

      assert.are.equal(1, #select_calls)
      assert.are.same({
        msg = "Rails: telescope.nvim not found, falling back to vim.ui.select",
        level = vim.log.levels.WARN,
      }, notifications[1])
    end)
  end)
end)
