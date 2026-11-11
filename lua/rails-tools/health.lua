local config = require("rails-tools.config")
local rails_detector = require("rails-tools.detectors.rails")
local test_framework_detector = require("rails-tools.detectors.test_framework")

local M = {}

local MIN_NVIM_VERSION = "0.9"
local RAILS_LOCK_PATTERNS = { "^    rails %((.-)%)", "^    railties %((.-)%)" }
local GRAPE_DETECTOR_FILE = "lua/rails-tools/detectors/grape.lua"

local OPTIONAL_DEPENDENCIES = {
  { module = "telescope", name = "telescope.nvim", fallback = "pickers fall back to vim.ui.select" },
  { module = "toggleterm", name = "toggleterm.nvim", fallback = "terminal falls back to the native terminal" },
  { module = "which-key", name = "which-key.nvim", fallback = "keymaps work without group labels" },
}

local TEST_FRAMEWORK_LABELS = {
  rspec = "RSpec",
  minitest = "Minitest",
  both = "RSpec and Minitest",
}

---@return string
local function nvim_version_text()
  local version = vim.version()

  return ("%d.%d.%d"):format(version.major, version.minor, version.patch)
end

---@param root string
---@param name string
---@return boolean
local function project_path_exists(root, name)
  local path = root .. "/" .. name

  return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

---@param root string
---@return string|nil
local function rails_version_from_lockfile(root)
  local lockfile = root .. "/Gemfile.lock"
  if vim.fn.filereadable(lockfile) ~= 1 then
    return nil
  end

  local lines = vim.fn.readfile(lockfile)
  for _, pattern in ipairs(RAILS_LOCK_PATTERNS) do
    for _, line in ipairs(lines) do
      local version = line:match(pattern)
      if version then
        return version
      end
    end
  end

  return nil
end

local function check_plugin_setup()
  if vim.api.nvim_get_commands({}).Rails then
    vim.health.ok("setup() called")
    return
  end

  vim.health.warn('setup() has not been called (add require("rails-tools").setup() to your config)')
end

local function check_ruby_version()
  if vim.fn.executable("ruby") ~= 1 then
    vim.health.warn("Ruby not found in PATH")
    return
  end

  local output = vim.fn.system({ "ruby", "-v" })
  if vim.v.shell_error ~= 0 then
    vim.health.warn("Ruby version could not be read: " .. vim.trim(output))
    return
  end

  vim.health.ok(vim.trim(vim.split(output, "\n")[1]))
end

---@param root string
local function check_rails_version(root)
  local version = rails_version_from_lockfile(root)
  if not version then
    vim.health.warn("Rails version not found in Gemfile.lock")
    return
  end

  vim.health.ok("Rails " .. version)
end

---@param root string|nil
local function check_environment(root)
  vim.health.start("Environment")
  vim.health.ok("Neovim " .. nvim_version_text())
  check_plugin_setup()

  if not root then
    vim.health.warn(
      ("Not a Rails project (no Gemfile + bin/rails or script/rails found from %s; "):format(vim.fn.getcwd())
        .. "detection is cached per session, restart Neovim after creating them)"
    )
    return
  end

  vim.health.ok("Rails project detected at " .. root)
  check_ruby_version()
  check_rails_version(root)
end

---@param root string
local function check_project_files(root)
  vim.health.ok("Gemfile found")

  if project_path_exists(root, "Gemfile.lock") then
    vim.health.ok("Gemfile.lock found")
  else
    vim.health.warn("Gemfile.lock not found")
  end

  local rails_executable = project_path_exists(root, "bin/rails") and "bin/rails" or "script/rails"
  vim.health.ok(rails_executable .. " found")
end

---@param root string
local function check_test_framework(root)
  local framework = test_framework_detector.detect(root)
  if not framework then
    vim.health.warn("No spec/ or test/ directory found")
    return
  end

  vim.health.ok("Test framework: " .. TEST_FRAMEWORK_LABELS[framework])
end

---@param root string
local function check_grape(root)
  if #vim.api.nvim_get_runtime_file(GRAPE_DETECTOR_FILE, false) == 0 then
    vim.health.info("Grape detection not available yet")
    return
  end

  if require("rails-tools.detectors.grape").detect(root) then
    vim.health.ok("Grape API detected")
  else
    vim.health.info("Grape API not detected")
  end
end

---@param root string|nil
local function check_project(root)
  vim.health.start("Project")

  if not root then
    vim.health.info("Skipped: not a Rails project")
    return
  end

  check_project_files(root)
  check_test_framework(root)
  check_grape(root)
end

local function check_optional_dependencies()
  vim.health.start("Optional dependencies")

  for _, dependency in ipairs(OPTIONAL_DEPENDENCIES) do
    if pcall(require, dependency.module) then
      vim.health.ok(dependency.name .. " installed")
    else
      vim.health.warn(("%s not installed (%s)"):format(dependency.name, dependency.fallback))
    end
  end
end

local function check_modules()
  vim.health.start("Modules")

  local modules = config.get().modules
  local names = vim.tbl_keys(modules)
  table.sort(names)

  for _, name in ipairs(names) do
    if modules[name] == true then
      vim.health.ok(name .. ": enabled")
    else
      vim.health.info(name .. ": disabled")
    end
  end
end

local function report_unsupported_nvim()
  vim.health.report_start("Environment")
  vim.health.report_error(
    ("Neovim %s is not supported (requires Neovim %s+)"):format(nvim_version_text(), MIN_NVIM_VERSION)
  )
end

---Entry point for `:checkhealth rails-tools`.
function M.check()
  if vim.fn.has("nvim-" .. MIN_NVIM_VERSION) ~= 1 then
    report_unsupported_nvim()
    return
  end

  local root = rails_detector.root()

  check_environment(root)
  check_project(root)
  check_optional_dependencies()
  check_modules()
end

return M
