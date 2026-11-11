local health
local config

local HEALTH_FUNCTIONS = { "start", "ok", "info", "warn", "error" }

describe("rails-tools.health", function()
  local tmp_dir
  local orig_cwd
  local orig_health
  local orig_executable
  local orig_has
  local orig_runtimepath
  local reports

  local function create_file(path, lines)
    local full = tmp_dir .. "/" .. path
    vim.fn.mkdir(vim.fn.fnamemodify(full, ":h"), "p")
    vim.fn.writefile(lines or {}, full)
  end

  local function create_rails_project()
    create_file("Gemfile")
    create_file("Gemfile.lock", { "GEM", "  specs:", "    rails (7.1.6)", "      actionpack (= 7.1.6)" })
    create_file("bin/rails")
    vim.fn.mkdir(tmp_dir .. "/spec", "p")
  end

  local function find_report(level, pattern)
    for _, report in ipairs(reports) do
      if report.level == level and report.msg:find(pattern, 1, true) then
        return report
      end
    end

    return nil
  end

  local function reports_in_section(section)
    local result = {}
    for _, report in ipairs(reports) do
      if report.section == section and report.level ~= "start" then
        table.insert(result, report)
      end
    end

    return result
  end

  before_each(function()
    orig_cwd = vim.fn.getcwd()
    tmp_dir = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(tmp_dir, "p")

    for _, name in ipairs({
      "rails-tools.health",
      "rails-tools.config",
      "rails-tools.detectors.rails",
      "rails-tools.detectors.test_framework",
    }) do
      package.loaded[name] = nil
    end
    health = require("rails-tools.health")
    config = require("rails-tools.config")
    config.setup({})

    reports = {}
    orig_health = {}
    local current_section
    for _, name in ipairs(HEALTH_FUNCTIONS) do
      orig_health[name] = vim.health[name]
      vim.health[name] = function(msg)
        if name == "start" then
          current_section = msg
        end
        table.insert(reports, { level = name, msg = msg, section = current_section })
      end
    end

    orig_executable = vim.fn.executable
    orig_has = vim.fn.has
    orig_runtimepath = vim.o.runtimepath
  end)

  after_each(function()
    for _, name in ipairs(HEALTH_FUNCTIONS) do
      vim.health[name] = orig_health[name]
    end
    vim.fn.executable = orig_executable
    vim.fn.has = orig_has
    vim.o.runtimepath = orig_runtimepath
    vim.cmd("silent! %bwipeout!")
    package.preload["telescope"] = nil
    package.loaded["telescope"] = nil
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_dir, "rf")
  end)

  describe("in a Rails project", function()
    before_each(function()
      create_rails_project()
      vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
    end)

    it("reports the detected Rails root", function()
      health.check()

      assert.is_not_nil(find_report("ok", "Rails project detected at " .. tmp_dir))
    end)

    it("reports the Rails version from Gemfile.lock", function()
      health.check()

      assert.is_not_nil(find_report("ok", "Rails 7.1.6"))
    end)

    it("warns when Gemfile.lock is missing", function()
      vim.fn.delete(tmp_dir .. "/Gemfile.lock")

      health.check()

      assert.is_not_nil(find_report("warn", "Rails version not found in Gemfile.lock"))
      assert.is_not_nil(find_report("warn", "Gemfile.lock not found"))
    end)

    it("falls back to the railties version when the rails gem is not locked", function()
      create_file("Gemfile.lock", { "GEM", "  specs:", "    railties (7.0.8)" })

      health.check()

      assert.is_not_nil(find_report("ok", "Rails 7.0.8"))
    end)

    it("warns when ruby is not executable", function()
      vim.fn.executable = function(name)
        if name == "ruby" then
          return 0
        end

        return orig_executable(name)
      end

      health.check()

      assert.is_not_nil(find_report("warn", "Ruby"))
    end)

    it("reports project files", function()
      health.check()

      assert.is_not_nil(find_report("ok", "Gemfile found"))
      assert.is_not_nil(find_report("ok", "bin/rails found"))
    end)

    it("reports RSpec as the test framework", function()
      health.check()

      assert.is_not_nil(find_report("ok", "Test framework: RSpec"))
    end)

    it("reports both frameworks when spec/ and test/ exist", function()
      vim.fn.mkdir(tmp_dir .. "/test", "p")

      health.check()

      assert.is_not_nil(find_report("ok", "Test framework: RSpec and Minitest"))
    end)

    it("warns when no test framework directory exists", function()
      vim.fn.delete(tmp_dir .. "/spec", "rf")

      health.check()

      assert.is_not_nil(find_report("warn", "No spec/ or test/ directory"))
    end)

    it("says Grape detection is not available while the detector does not exist", function()
      health.check()

      assert.is_not_nil(find_report("info", "Grape detection not available yet"))
    end)
  end)

  describe("outside a Rails project", function()
    before_each(function()
      vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
    end)

    it("warns instead of erroring", function()
      assert.has_no.errors(function()
        health.check()
      end)

      assert.is_not_nil(find_report("warn", "Not a Rails project"))
    end)

    it("skips the project section and version checks", function()
      health.check()

      local project_reports = reports_in_section("Project")
      assert.equals(1, #project_reports)
      assert.equals("info", project_reports[1].level)
      assert.is_nil(find_report("ok", "Rails 7"))
      assert.is_nil(find_report("ok", "ruby "))
    end)
  end)

  describe("optional dependencies", function()
    it("reports an installed dependency as ok", function()
      package.preload["telescope"] = function()
        return {}
      end

      health.check()

      assert.is_not_nil(find_report("ok", "telescope.nvim installed"))
    end)

    it("warns about a missing dependency with its fallback", function()
      health.check()

      local report = find_report("warn", "toggleterm.nvim not installed")
      assert.is_not_nil(report)
      assert.is_truthy(report.msg:find("native terminal", 1, true))
    end)

    it("checks which-key.nvim", function()
      health.check()

      assert.is_not_nil(find_report("warn", "which-key.nvim not installed"))
    end)
  end)

  describe("modules", function()
    it("reports enabled and disabled modules", function()
      config.setup({ modules = { rspec = true } })

      health.check()

      assert.is_not_nil(find_report("ok", "rspec: enabled"))
      assert.is_not_nil(find_report("info", "gf: disabled"))
    end)
  end)

  describe("plugin setup", function()
    it("warns when :Rails is not registered", function()
      pcall(vim.api.nvim_del_user_command, "Rails")

      health.check()

      assert.is_not_nil(find_report("warn", "setup() has not been called"))
    end)

    it("reports ok when :Rails is registered", function()
      vim.api.nvim_create_user_command("Rails", function() end, {})

      health.check()

      assert.is_not_nil(find_report("ok", "setup() called"))
      vim.api.nvim_del_user_command("Rails")
    end)
  end)

  it("runs through :checkhealth rails-tools without a Lua error", function()
    for _, name in ipairs(HEALTH_FUNCTIONS) do
      vim.health[name] = orig_health[name]
    end
    vim.opt.runtimepath:append(orig_cwd)
    create_rails_project()
    vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))

    vim.cmd("checkhealth rails-tools")

    local output = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    assert.is_truthy(output:find("rails-tools", 1, true))
    assert.is_truthy(output:find("Rails 7.1.6", 1, true))
    assert.is_falsy(output:find("Failed to run healthcheck", 1, true))
    assert.is_falsy(output:find("ERROR", 1, true))
  end)

  it("reports an unsupported Neovim version with the pre-0.9 health API", function()
    local legacy_reports = {}
    local orig_report_start = vim.health.report_start
    local orig_report_error = vim.health.report_error
    vim.health.report_start = function(msg)
      table.insert(legacy_reports, { level = "start", msg = msg })
    end
    vim.health.report_error = function(msg)
      table.insert(legacy_reports, { level = "error", msg = msg })
    end
    vim.fn.has = function(feature)
      if feature == "nvim-0.9" then
        return 0
      end

      return orig_has(feature)
    end

    local ok = pcall(health.check)

    vim.health.report_start = orig_report_start
    vim.health.report_error = orig_report_error
    assert.is_true(ok)
    assert.equals("error", legacy_reports[2].level)
    assert.is_truthy(legacy_reports[2].msg:find("requires Neovim 0.9+", 1, true))
    assert.equals(0, #reports)
  end)

  it("reports the Neovim version as ok", function()
    health.check()

    local version = vim.version()
    local version_text = ("%d.%d.%d"):format(version.major, version.minor, version.patch)

    assert.is_not_nil(find_report("ok", "Neovim " .. version_text))
  end)
end)
