local M = {}
local uv = vim.loop

local function relpath(filepath)
  if not filepath or filepath == "" then return "" end
  local cwd = uv.cwd()
  -- if filepath starts with cwd + '/', strip it
  if filepath:sub(1, #cwd + 1) == cwd .. '/' then
    return filepath:sub(#cwd + 2)
  end
  -- if it's an absolute path not under cwd, strip leading '/'
  if filepath:sub(1,1) == '/' then
    return filepath:sub(2)
  end
  return filepath
end

local function load_mappings()
  local ok, cfg = pcall(require, "rails-tools.config")
  if ok and cfg and cfg.mappings then
    return cfg.mappings
  end
  return {}
end

-- Returns alternate path relative to project root (string) or nil if none
function M.get(filepath)
  local path = relpath(filepath)
  local maps = load_mappings()
  for _, m in ipairs(maps) do
    local from = m.from
    local to = m.to
    local res, n = path:gsub(from, to)
    if n > 0 then
      return res
    end
  end
  return nil
end

function M.open()
  local bufname = vim.api.nvim_buf_get_name(0)
  local target = M.get(bufname)
  if not target then
    vim.notify("No alternate found for " .. bufname, vim.log.levels.INFO)
    return
  end
  local cwd = uv.cwd()
  local target_abs = cwd .. "/" .. target
  if uv.fs_stat(target_abs) then
    vim.cmd("edit " .. target_abs)
  else
    local choice = vim.fn.input("Create " .. target .. " ? (y/N): ")
    if choice:lower():match("^y") then
      -- ensure directory exists
      local dir = target_abs:match("^(.+)/[^/]+$")
      if dir then
        os.execute("mkdir -p " .. dir)
      end
      local fh = io.open(target_abs, "w")
      if fh then fh:write("") fh:close() end
      vim.cmd("edit " .. target_abs)
    end
  end
end

return M
