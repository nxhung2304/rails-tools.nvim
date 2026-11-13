local rails = require("rails-tools.detectors.rails")

local M = {}

local API_DIR = "app/api"
local GEMFILE = "Gemfile"
local GRAPE_GEM_PATTERN = "^%s*gem%s*%(?%s*[\"']grape[\"']"

---@type table<string, boolean>
local cache = {}

---@param gemfile_path string
---@return boolean
local function gemfile_has_grape(gemfile_path)
  if vim.fn.filereadable(gemfile_path) == 0 then
    return false
  end

  for _, line in ipairs(vim.fn.readfile(gemfile_path)) do
    if line:match(GRAPE_GEM_PATTERN) then
      return true
    end
  end

  return false
end

---@param dir string
---@return boolean
local function detect_in_dir(dir)
  return vim.fn.isdirectory(dir .. "/" .. API_DIR) == 1 and gemfile_has_grape(dir .. "/" .. GEMFILE)
end

---Detects a Grape API: both `app/api/` and a `gem "grape"` line in the Gemfile must exist.
---@param cwd? string
---@return boolean
function M.detect(cwd)
  local start_dir = cwd or vim.fn.getcwd()
  if cache[start_dir] ~= nil then
    return cache[start_dir]
  end

  local project_dir = rails.root(start_dir) or start_dir
  if cache[project_dir] == nil then
    cache[project_dir] = detect_in_dir(project_dir)
  end

  cache[start_dir] = cache[project_dir]
  return cache[start_dir]
end

return M
