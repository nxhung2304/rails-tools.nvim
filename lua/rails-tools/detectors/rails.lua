local M = {}

---@type table<string, {is_rails: boolean, root: string}|false>
local cache = {}

---@param dir string
---@param name string
---@return boolean
local function file_exists(dir, name)
  local path = dir .. "/" .. name
  return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

---@param start_dir string
---@return string|nil
local function find_root(start_dir)
  local dir = start_dir
  while true do
    local has_gemfile = vim.fn.filereadable(dir .. "/Gemfile") == 1
    local has_rails = file_exists(dir, "bin/rails") or file_exists(dir, "script/rails")
    if has_gemfile and has_rails then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      return nil
    end
    dir = parent
  end
end

---@param cwd? string
---@return {is_rails: boolean, root: string}|nil
function M.detect(cwd)
  local start_dir = cwd or vim.fn.getcwd()
  if cache[start_dir] ~= nil then
    return cache[start_dir] or nil
  end
  local root = find_root(start_dir)
  if root then
    if cache[root] == nil then
      cache[root] = { is_rails = true, root = root }
    end
    local result = cache[root]
    cache[start_dir] = result
    ---@cast result {is_rails: boolean, root: string}
    return result
  end
  cache[start_dir] = false
  return nil
end

---@return string|nil
function M.root()
  local result = M.detect()
  return result and result.root or nil
end

---@return boolean
function M.is_rails()
  return M.detect() ~= nil
end

return M
