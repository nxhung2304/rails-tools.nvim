local MODULES_TO_RELOAD = {
  "rails-tools.core.routes",
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

local FIXTURE_DIR = vim.fn.fnamemodify("tests/fixtures/routes", ":p")
local EXPANDED_FIXTURE = FIXTURE_DIR .. "expanded.txt"
local ENGINE_FIXTURE = FIXTURE_DIR .. "expanded_with_engine.txt"
local JOB_WAIT_MS = 5000

local function read_fixture(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

local function find_route(routes, controller_action, verb)
  for _, route in ipairs(routes) do
    if route.controller_action == controller_action and (verb == nil or route.verb == verb) then
      return route
    end
  end
  return nil
end

describe("rails-tools.core.routes", function()
  local routes
  local config
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

  local function create_file(relative_path, lines)
    local path = tmp_dir .. "/" .. relative_path
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile(lines or {}, path)
  end

  local function use_routes_command(command, args)
    config.setup({ finder = { provider = "native" }, routes = { command = command, args = args } })
  end

  local function wait_for_picker(expected_calls)
    vim.wait(JOB_WAIT_MS, function()
      return #select_calls >= (expected_calls or 1)
    end)
  end

  local function messages()
    return vim.tbl_map(function(notification)
      return notification.msg
    end, notifications)
  end

  local function wait_for_message(pattern)
    vim.wait(JOB_WAIT_MS, function()
      for _, msg in ipairs(messages()) do
        if msg:match(pattern) then
          return true
        end
      end
      return false
    end)
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
      on_choice(select_choice and select_choice(items) or nil)
    end

    config = require("rails-tools.config")
    use_routes_command("cat", EXPANDED_FIXTURE)
    routes = require("rails-tools.core.routes")

    create_file("Gemfile")
    create_file("bin/rails")
    vim.cmd("enew!")
    vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
  end)

  after_each(function()
    routes.stop()
    vim.notify = orig_notify
    vim.ui.select = orig_select
    remove_fake_telescope()
    vim.cmd("silent! %bwipeout!")
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_dir, "rf")
    reload_modules()
  end)

  describe("parse()", function()
    it("reads every --expanded block", function()
      local parsed = routes.parse(read_fixture(EXPANDED_FIXTURE))

      assert.are.equal(42, #parsed)
    end)

    it("reads prefix, verb, URI, controller#action and source location", function()
      local parsed = routes.parse(read_fixture(EXPANDED_FIXTURE))

      assert.are.same({
        name = "users",
        verb = "GET",
        path = "/users(.:format)",
        controller_action = "users#index",
        source_location = "/app/config/routes.rb:8",
      }, parsed[4])
    end)

    it("keeps an empty prefix as an empty name", function()
      local parsed = routes.parse(read_fixture(EXPANDED_FIXTURE))

      assert.are.equal("", find_route(parsed, "users#create").name)
    end)

    it("reads namespaced controllers", function()
      local parsed = routes.parse(read_fixture(EXPANDED_FIXTURE))

      assert.is_not_nil(find_route(parsed, "admin/users#index"))
    end)

    it("works without a Source Location field", function()
      local output = table.concat({
        "--[ Route 1 ]-------------------------------------------------------------------",
        "Prefix            | users",
        "Verb              | GET",
        "URI               | /users(.:format)",
        "Controller#Action | users#index",
      }, "\n")

      assert.are.same({
        { name = "users", verb = "GET", path = "/users(.:format)", controller_action = "users#index" },
      }, routes.parse(output))
    end)

    it("marks routes of a mounted engine with the engine name", function()
      local parsed = routes.parse(read_fixture(ENGINE_FIXTURE))

      local engine_route = find_route(parsed, "blog/posts#index")
      assert.are.equal("Blog::Engine", engine_route.engine)
      assert.are.equal("/posts(.:format)", engine_route.path)
      assert.is_nil(find_route(parsed, "users#index").engine)
    end)

    it("lists mounts, inline handlers and redirects", function()
      local parsed = routes.parse(read_fixture(ENGINE_FIXTURE))

      assert.are.equal("", find_route(parsed, "Blog::Engine").verb)
      assert.is_not_nil(find_route(parsed, "Inline handler (Proc/Lambda)"))
      assert.is_not_nil(find_route(parsed, "redirect(301, /new)"))
    end)

    it("returns an empty list for empty output", function()
      assert.are.same({}, routes.parse(""))
    end)
  end)

  describe("controller_location()", function()
    it("maps controller#action to the controller file and action", function()
      assert.are.same(
        { path = "app/controllers/users_controller.rb", action = "index" },
        routes.controller_location("users#index")
      )
    end)

    it("maps a namespaced controller to its subdirectory", function()
      assert.are.same(
        { path = "app/controllers/admin/users_controller.rb", action = "index" },
        routes.controller_location("admin/users#index")
      )
    end)

    it("returns nil for routes without a controller action", function()
      assert.is_nil(routes.controller_location("Blog::Engine"))
      assert.is_nil(routes.controller_location("Inline handler (Proc/Lambda)"))
      assert.is_nil(routes.controller_location("redirect(301, /new)"))
      assert.is_nil(routes.controller_location(""))
    end)
  end)

  describe("method_line()", function()
    it("finds the line of def <action>", function()
      create_file("app/controllers/users_controller.rb", {
        "class UsersController < ApplicationController",
        "  def index_all; end",
        "  def index",
        "  end",
        "end",
      })

      assert.are.equal(3, routes.method_line(tmp_dir .. "/app/controllers/users_controller.rb", "index"))
    end)

    it("returns nil when the action is not defined", function()
      create_file("app/controllers/users_controller.rb", { "class UsersController", "end" })

      assert.is_nil(routes.method_line(tmp_dir .. "/app/controllers/users_controller.rb", "index"))
    end)
  end)

  describe("goto_action()", function()
    it("opens the controller at def <action>", function()
      create_file("app/controllers/users_controller.rb", {
        "class UsersController < ApplicationController",
        "  def show",
        "  end",
        "",
        "  def index",
        "  end",
        "end",
      })

      routes.goto_action({ controller_action = "users#index" })

      assert.are.equal(tmp_dir .. "/app/controllers/users_controller.rb", vim.api.nvim_buf_get_name(0))
      assert.are.equal(5, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("opens a namespaced controller at def <action>", function()
      create_file("app/controllers/admin/users_controller.rb", {
        "module Admin",
        "  class UsersController < ApplicationController",
        "    def index",
        "    end",
        "  end",
        "end",
      })

      routes.goto_action({ controller_action = "admin/users#index" })

      assert.are.equal(tmp_dir .. "/app/controllers/admin/users_controller.rb", vim.api.nvim_buf_get_name(0))
      assert.are.equal(3, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("shows a notice for a route without a controller action", function()
      routes.goto_action({ controller_action = "redirect(301, /new)" })

      assert.are.same({
        { msg = "Rails: redirect(301, /new) has no controller action to open", level = vim.log.levels.INFO },
      }, notifications)
      assert.are.equal("", vim.api.nvim_buf_get_name(0))
    end)

    it("shows a notice when the controller file does not exist", function()
      routes.goto_action({ controller_action = "blog/posts#index" })

      assert.are.same({
        { msg = "Rails: app/controllers/blog/posts_controller.rb not found", level = vim.log.levels.INFO },
      }, notifications)
      assert.are.equal("", vim.api.nvim_buf_get_name(0))
    end)

    it("opens the controller at the top when the action is not defined", function()
      create_file("app/controllers/users_controller.rb", { "class UsersController", "end" })

      routes.goto_action({ controller_action = "users#index" })

      assert.are.equal(tmp_dir .. "/app/controllers/users_controller.rb", vim.api.nvim_buf_get_name(0))
      assert.are.equal(1, vim.api.nvim_win_get_cursor(0)[1])
      assert.are.same({
        { msg = "Rails: def index not found in app/controllers/users_controller.rb", level = vim.log.levels.INFO },
      }, notifications)
    end)
  end)

  describe("show()", function()
    it("warns outside a Rails project", function()
      vim.fn.delete(tmp_dir .. "/Gemfile")

      routes.show()

      assert.are.same({ { msg = "Rails: not a Rails project", level = vim.log.levels.WARN } }, notifications)
    end)

    it("shows a loading notice, then lists the routes without blocking", function()
      routes.show()

      assert.are.same({ "Rails: loading routes..." }, messages())
      assert.are.equal(0, #select_calls)

      wait_for_picker()

      assert.are.equal(1, #select_calls)
      assert.are.equal(42, #select_calls[1].items)
      assert.are.equal("Rails routes", select_calls[1].opts.prompt)
    end)

    it("formats each route with verb, URI, controller#action and name", function()
      routes.show()
      wait_for_picker()

      local format_item = select_calls[1].opts.format_item
      assert.are.equal(
        "GET     /users(.:format)  users#index  (users)",
        format_item({ verb = "GET", path = "/users(.:format)", controller_action = "users#index", name = "users" })
      )
      assert.are.equal(
        "[Blog::Engine] GET     /posts(.:format)  blog/posts#index",
        format_item({
          verb = "GET",
          path = "/posts(.:format)",
          controller_action = "blog/posts#index",
          name = "",
          engine = "Blog::Engine",
        })
      )
    end)

    it("jumps to the chosen route", function()
      create_file("app/controllers/users_controller.rb", { "class UsersController", "  def index", "  end", "end" })
      select_choice = function(items)
        return find_route(items, "users#index", "GET")
      end

      routes.show()
      wait_for_picker()

      assert.are.equal(tmp_dir .. "/app/controllers/users_controller.rb", vim.api.nvim_buf_get_name(0))
      assert.are.equal(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("uses the cache on the next call without running the command again", function()
      routes.show()
      wait_for_picker()
      use_routes_command("sh", "-c 'exit 7'")
      notifications = {}

      routes.show()

      assert.are.equal(2, #select_calls)
      assert.are.same({}, notifications)
    end)

    it("runs the command again once the cache TTL has passed", function()
      config.setup({
        finder = { provider = "native" },
        routes = { command = "cat", args = EXPANDED_FIXTURE, cache_ttl = 0 },
      })
      routes.show()
      wait_for_picker()
      notifications = {}

      routes.show()

      assert.are.same({ "Rails: loading routes..." }, messages())
      wait_for_picker(2)
      assert.are.equal(2, #select_calls)
    end)

    it("shows the exit code and stderr when the command fails", function()
      use_routes_command("sh", "-c 'echo first line >&2; echo >&2; echo boom >&2; exit 3'")

      routes.show()
      wait_for_message("failed")

      assert.are.same({
        msg = "Rails: routes command failed (exit 3)\nfirst line\nboom",
        level = vim.log.levels.ERROR,
      }, notifications[2])
      assert.are.equal(0, #select_calls)
    end)

    it("shows only the first 20 lines of stderr", function()
      use_routes_command("sh", "-c 'for i in $(seq 1 30); do echo line$i >&2; done; exit 1'")

      routes.show()
      wait_for_message("failed")

      local lines = vim.split(notifications[2].msg, "\n")
      assert.are.equal(21, #lines)
      assert.are.equal("line20", lines[21])
    end)

    it("shows a notice when the output has no routes", function()
      use_routes_command("true", "")

      routes.show()
      wait_for_message("no routes")

      assert.are.same({ msg = "Rails: no routes found", level = vim.log.levels.INFO }, notifications[2])
      assert.are.equal(0, #select_calls)
    end)

    it("does not start a second command while one is running", function()
      use_routes_command("sleep", "5")

      routes.show()
      routes.show()

      assert.are.same({
        "Rails: loading routes...",
        "Rails: routes are still loading (:Rails routes! to restart)",
      }, messages())
    end)
  end)

  describe("refresh()", function()
    it("runs the command again even when routes are cached", function()
      routes.show()
      wait_for_picker()
      notifications = {}

      routes.refresh()

      assert.are.same({ "Rails: loading routes..." }, messages())
      wait_for_picker(2)
      assert.are.equal(2, #select_calls)
    end)

    it("stops a running command without reporting it as failed", function()
      use_routes_command("sleep", "5")
      routes.show()
      use_routes_command("cat", EXPANDED_FIXTURE)

      routes.refresh()
      wait_for_picker()
      vim.wait(200)

      assert.are.same({ "Rails: loading routes...", "Rails: loading routes..." }, messages())
      assert.are.equal(1, #select_calls)
    end)
  end)

  describe("Telescope picker", function()
    local picker_specs
    local picker_opts_calls
    local select_default_handler

    local function install_fake_telescope(selected_entry)
      picker_specs = {}
      picker_opts_calls = {}
      package.preload["telescope"] = function()
        return {}
      end
      package.preload["telescope.pickers"] = function()
        return {
          new = function(picker_opts, spec)
            table.insert(picker_opts_calls, picker_opts)
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
        return { values = { generic_sorter = function() return "sorter" end } }
      end
      package.preload["telescope.actions"] = function()
        return {
          select_default = {
            replace = function(_, handler)
              select_default_handler = handler
            end,
          },
          close = function() end,
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

    it("lists routes in Telescope and opens the selected one", function()
      create_file("app/controllers/users_controller.rb", { "class UsersController", "  def index", "  end", "end" })
      install_fake_telescope({ value = { controller_action = "users#index" } })

      routes.show({ provider = "telescope", picker_opts = { layout_strategy = "vertical" } })
      vim.wait(JOB_WAIT_MS, function()
        return #picker_specs > 0
      end)
      select_default_handler()

      assert.are.equal("Rails routes", picker_specs[1].prompt_title)
      assert.are.equal(42, #picker_specs[1].finder.results)
      assert.are.same({ { layout_strategy = "vertical" } }, picker_opts_calls)
      assert.are.equal(0, #select_calls)
      assert.are.equal(tmp_dir .. "/app/controllers/users_controller.rb", vim.api.nvim_buf_get_name(0))
      assert.are.equal(2, vim.api.nvim_win_get_cursor(0)[1])
    end)
  end)
end)
