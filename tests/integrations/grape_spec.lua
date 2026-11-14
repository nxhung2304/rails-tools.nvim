local MODULES_TO_RELOAD = {
  "rails-tools.integrations.grape",
  "rails-tools.config",
  "rails-tools.detectors.rails",
  "rails-tools.cache",
}

local ROUTES_FIXTURE = vim.fn.fnamemodify("tests/fixtures/grape/routes.txt", ":p")
local JOB_WAIT_MS = 5000
local EXIT_CALLBACK_WAIT_MS = 20

local function read_fixture(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

describe("rails-tools.integrations.grape", function()
  local grape
  local config
  local tmp_dir
  local orig_cwd
  local notifications
  local orig_notify
  local orig_select
  local select_calls
  local select_choice

  local function reload_modules()
    for _, name in ipairs(MODULES_TO_RELOAD) do
      package.loaded[name] = nil
    end
  end

  local function job_channels()
    return vim.tbl_filter(function(channel)
      return channel.stream == "job"
    end, vim.api.nvim_list_chans())
  end

  local function stop_running_jobs()
    for _, channel in ipairs(job_channels()) do
      vim.fn.jobstop(channel.id)
    end
    vim.wait(JOB_WAIT_MS, function()
      return #job_channels() == 0
    end)
    vim.wait(EXIT_CALLBACK_WAIT_MS)
  end

  local function create_file(relative_path, lines)
    local path = tmp_dir .. "/" .. relative_path
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile(lines or {}, path)
  end

  local function use_runner_command(command, cache_ttl)
    config.setup({
      finder = { provider = "native" },
      runner = { command = command },
      routes = { cache_ttl = cache_ttl },
    })
  end

  local function shell_runner(script)
    return "sh -c " .. vim.fn.shellescape(script)
  end

  local function messages()
    return vim.tbl_map(function(notification)
      return notification.msg
    end, notifications)
  end

  local function wait_for_picker(expected_calls)
    vim.wait(JOB_WAIT_MS, function()
      return #select_calls >= (expected_calls or 1)
    end)
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
    use_runner_command(shell_runner("cat " .. vim.fn.shellescape(ROUTES_FIXTURE)))
    grape = require("rails-tools.integrations.grape")

    create_file("Gemfile")
    create_file("bin/rails")
    vim.cmd("enew!")
    vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
  end)

  after_each(function()
    stop_running_jobs()
    vim.notify = orig_notify
    vim.ui.select = orig_select
    vim.cmd("enew!")
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_dir, "rf")
    reload_modules()
  end)

  describe("parse()", function()
    it("parses every endpoint of a captured listing", function()
      local parsed = grape.parse(read_fixture(ROUTES_FIXTURE))

      assert.are.equal(4, #parsed)
      assert.are.same({
        verb = "GET",
        path = "/api/v1/users",
        description = "List users",
        api = "BaseApi",
        file = "/projects/test-app/app/api/v1/users.rb",
        line = 7,
      }, parsed[1])
      assert.are.same("POST", parsed[3].verb)
      assert.are.same("/api/v1/users/:id/deactivate", parsed[3].path)
      assert.are.same("", parsed[4].description)
    end)

    it("ignores warnings and other output printed by the app", function()
      local output = table.concat({
        "DEPRECATION WARNING: something",
        read_fixture(ROUTES_FIXTURE),
        "RAILS_TOOLS_GRAPE_ROUTE {not json",
        "RAILS_TOOLS_GRAPE_ROUTE []",
        "",
      }, "\n")

      assert.are.equal(4, #grape.parse(output))
    end)

    it("keeps an endpoint without a source location", function()
      local parsed = grape.parse('RAILS_TOOLS_GRAPE_ROUTE {"verb":"GET","path":"/ping","file":null,"line":null}')

      assert.are.same({ verb = "GET", path = "/ping", description = "", api = "" }, parsed[1])
    end)

    it("returns an empty list when there is no Grape route", function()
      assert.are.same({}, grape.parse(""))
    end)
  end)

  describe("goto_endpoint()", function()
    it("opens the endpoint file at its line", function()
      create_file("app/api/v1/users.rb", { "module V1", "  class Users", "    get do", "    end", "  end", "end" })

      grape.goto_endpoint({ verb = "GET", path = "/users", file = tmp_dir .. "/app/api/v1/users.rb", line = 3 })

      assert.are.equal(tmp_dir .. "/app/api/v1/users.rb", vim.api.nvim_buf_get_name(0))
      assert.are.equal(3, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("resolves a relative file from the Rails root", function()
      create_file("app/api/health.rb", { "class Health", "  get :ping do", "  end", "end" })

      grape.goto_endpoint({ verb = "GET", path = "/ping", file = "app/api/health.rb", line = 2 })

      assert.are.equal(tmp_dir .. "/app/api/health.rb", vim.api.nvim_buf_get_name(0))
      assert.are.equal(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("stops at the last line when the file is shorter than the recorded line", function()
      create_file("app/api/health.rb", { "class Health", "end" })

      grape.goto_endpoint({ verb = "GET", path = "/ping", file = "app/api/health.rb", line = 40 })

      assert.are.equal(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("shows a notice when the endpoint has no source location", function()
      grape.goto_endpoint({ verb = "GET", path = "/ping" })

      assert.are.same({
        { msg = "Rails: no source location for GET /ping", level = vim.log.levels.INFO },
      }, notifications)
      assert.are.equal("", vim.api.nvim_buf_get_name(0))
    end)

    it("shows a notice when the endpoint file does not exist", function()
      grape.goto_endpoint({ verb = "GET", path = "/ping", file = "app/api/missing.rb", line = 1 })

      assert.are.same({ { msg = "Rails: app/api/missing.rb not found", level = vim.log.levels.INFO } }, notifications)
    end)
  end)

  describe("show()", function()
    it("warns outside a Rails project", function()
      vim.fn.delete(tmp_dir .. "/Gemfile")

      grape.show()

      assert.are.same({ { msg = "Rails: not a Rails project", level = vim.log.levels.WARN } }, notifications)
    end)

    it("passes the listing script to runner.command and lists the endpoints", function()
      grape.show()

      assert.are.same({ "Rails: loading Grape routes..." }, messages())
      wait_for_picker()

      assert.are.equal(1, #select_calls)
      assert.are.equal("Grape endpoints", select_calls[1].opts.prompt)
      assert.are.equal(4, #select_calls[1].items)
      assert.are.equal(
        "POST    /api/v1/users/:id/deactivate  (Deactivate a user)",
        select_calls[1].opts.format_item(select_calls[1].items[3])
      )
      assert.are.equal("GET     /api/v1/ping", select_calls[1].opts.format_item(select_calls[1].items[4]))
    end)

    it("sends the Ruby listing script as one argument of the runner command", function()
      local captured = tmp_dir .. "/script.rb"
      use_runner_command(shell_runner('printf "%s" "$0" > ' .. vim.fn.shellescape(captured)))

      grape.show()
      wait_for_message("no Grape routes found")

      local script = table.concat(vim.fn.readfile(captured), "\n")
      assert.is_truthy(script:find("Grape::API", 1, true))
      assert.is_truthy(script:find("source_location", 1, true))
    end)

    it("opens the chosen endpoint", function()
      create_file("app/api/v1/health.rb", { "module V1", "  class Health", "    get :ping do", "    end", "  end", "end" })
      local listing = ('RAILS_TOOLS_GRAPE_ROUTE {"verb":"GET","path":"/api/v1/ping","file":"%s","line":3}'):format(
        tmp_dir .. "/app/api/v1/health.rb"
      )
      use_runner_command(shell_runner("echo " .. vim.fn.shellescape(listing)))
      select_choice = function(items)
        return items[1]
      end

      grape.show()
      wait_for_picker()

      assert.are.equal(tmp_dir .. "/app/api/v1/health.rb", vim.api.nvim_buf_get_name(0))
      assert.are.equal(3, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("uses the cache on the next call", function()
      grape.show()
      wait_for_picker()

      grape.show()

      assert.are.equal(2, #select_calls)
      assert.are.same({ "Rails: loading Grape routes..." }, messages())
    end)

    it("runs the listing again once the cache is older than routes.cache_ttl", function()
      use_runner_command(shell_runner("cat " .. vim.fn.shellescape(ROUTES_FIXTURE)), 0)

      grape.show()
      wait_for_picker()
      grape.show()
      wait_for_picker(2)

      assert.are.same({ "Rails: loading Grape routes...", "Rails: loading Grape routes..." }, messages())
    end)

    it("says when the app has no Grape route", function()
      use_runner_command(shell_runner("echo booted"))

      grape.show()
      wait_for_message("no Grape routes")

      assert.are.equal(0, #select_calls)
      assert.are.same({
        "Rails: loading Grape routes...",
        "Rails: no Grape routes found (is the Grape API mounted in config/routes.rb?)",
      }, messages())
    end)

    it("shows the error output when the command fails", function()
      use_runner_command(shell_runner("echo boot failed >&2; exit 2"))

      grape.show()
      wait_for_message("failed")

      assert.are.same({
        msg = "Rails: Grape routes command failed (exit 2)\nboot failed",
        level = vim.log.levels.ERROR,
      }, notifications[2])
      assert.are.equal(0, #select_calls)
    end)

    it("does not start a second listing while one is running", function()
      use_runner_command(shell_runner("sleep 5"))

      grape.show()
      grape.show()

      assert.are.same({
        "Rails: loading Grape routes...",
        "Rails: Grape routes are still loading (:Rails grape routes! to restart)",
      }, messages())
    end)

    it("reports a command that cannot be started without erroring", function()
      local orig_jobstart = vim.fn.jobstart
      vim.fn.jobstart = function()
        return -1
      end

      local ok = pcall(grape.show)
      vim.fn.jobstart = orig_jobstart

      assert.is_true(ok)
      assert.are.same(vim.log.levels.ERROR, notifications[2].level)
    end)
  end)

  describe("refresh()", function()
    it("ignores the cache and lists the endpoints again", function()
      grape.show()
      wait_for_picker()

      grape.refresh()
      wait_for_picker(2)

      assert.are.same({ "Rails: loading Grape routes...", "Rails: loading Grape routes..." }, messages())
    end)

    it("restarts a running listing", function()
      use_runner_command(shell_runner("sleep 5"))
      grape.show()

      use_runner_command(shell_runner("cat " .. vim.fn.shellescape(ROUTES_FIXTURE)))
      grape.refresh()
      wait_for_picker()

      assert.are.equal(1, #select_calls)
    end)
  end)
end)
