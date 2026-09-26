local rails = require("rails-tools.detectors.rails")

local M = {}

---@type table<string, "rspec"|"minitest"|false>
local cache = {}

---@param dir string
---@return boolean
local function has_rspec_rails_gem(dir)
  local gemfile = dir .. "/Gemfile"
  if vim.fn.filereadable(gemfile) ~= 1 then
    return false
  end

  for _, line in ipairs(vim.fn.readfile(gemfile)) do
    if line:match("gem%s*[%(%s]*['\"]rspec%-rails['\"]") then
      return true
    end
  end

  return false
end

---@param dir string
---@return "rspec"|"minitest"|"both"|nil
local function detect_in_dir(dir)
  local has_spec = vim.fn.isdirectory(dir .. "/spec") == 1
  local has_test = vim.fn.isdirectory(dir .. "/test") == 1

  if has_spec and has_test then
    return "both"
  end

  if has_spec then
    return "rspec"
  end

  if has_test then
    return "minitest"
  end

  return nil
end

---@param cwd? string
---@return "rspec"|"minitest"|"both"|nil
function M.detect(cwd)
  local start_dir = cwd or vim.fn.getcwd()
  if cache[start_dir] ~= nil then
    return cache[start_dir] or nil
  end

  local project_dir = rails.root(start_dir) or start_dir
  if cache[project_dir] == nil then
    cache[project_dir] = detect_in_dir(project_dir) or false
  end

  local result = cache[project_dir]
  cache[start_dir] = result
  return result or nil
end

---@param cwd? string
---@return boolean
function M.is_rspec(cwd)
  return M.detect(cwd) == "rspec"
end

---@param cwd? string
---@return boolean
function M.is_minitest(cwd)
  return M.detect(cwd) == "minitest"
end

---@param cwd? string
---@return boolean
function M.has_both(cwd)
  return M.detect(cwd) == "both"
end

---@return string[]
function M.available_frameworks(cwd)
  local detected = M.detect(cwd)
  if detected == "both" then
    return { "rspec", "minitest" }
  elseif detected == "rspec" then
    return { "rspec" }
  elseif detected == "minitest" then
    return { "minitest" }
  else
    return {}
  end
end

return M
