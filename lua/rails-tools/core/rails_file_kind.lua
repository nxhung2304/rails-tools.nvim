local M = {}

M.LAYOUTS_FOLDER = "layouts"
local HIDDEN_SECTION_PATTERNS = { "^%s*private%s*$", "^%s*protected%s*$" }
local HIDDEN_DEF_PATTERNS = { "^%s*private%s+def%s", "^%s*protected%s+def%s" }
local DEF_PATTERN = "^%s*def%s+([%w_]+[?!]?)%s*([%.]?)"

---@class RailsFileKind
---@field kind "controller"|"view"|"model"|"migration"|"helper"
---@field path? string controller, model or helper path, e.g. `admin/users`
---@field folder? string view folder under app/views
---@field action? string view file name before the first `.`
---@field is_partial? boolean
---@field is_layout? boolean

---What kind of Rails file `relative_file` is, nil when it has no related files.
---@param relative_file string path relative to the Rails root
---@return RailsFileKind|nil
function M.kind_of(relative_file)
  local controller_path = relative_file:match("^app/controllers/(.+)_controller%.rb$")
  if controller_path then
    return { kind = "controller", path = controller_path }
  end
  local folder, file_name = relative_file:match("^app/views/(.+)/([^/]+)$")
  local action = file_name and file_name:match("^([^.]+)")
  if action then
    local is_layout_folder = folder == M.LAYOUTS_FOLDER
    local is_inside_layouts = folder:sub(1, #M.LAYOUTS_FOLDER + 1) == M.LAYOUTS_FOLDER .. "/"
    return {
      kind = "view",
      folder = folder,
      action = action,
      is_partial = action:sub(1, 1) == "_",
      is_layout = is_layout_folder or is_inside_layouts,
    }
  end
  local model_path = relative_file:match("^app/models/(.+)%.rb$")
  if model_path and not model_path:match("^concerns/") then
    return { kind = "model", path = model_path }
  end
  if relative_file:match("^db/migrate/.+%.rb$") then
    return { kind = "migration" }
  end
  local helper_path = relative_file:match("^app/helpers/(.+)_helper%.rb$")
  if helper_path then
    return { kind = "helper", path = helper_path }
  end
  return nil
end

---@param line string
---@param patterns string[]
---@return boolean
local function matches_any(line, patterns)
  for _, pattern in ipairs(patterns) do
    if line:match(pattern) then
      return true
    end
  end
  return false
end

---Public action whose `def` is the nearest one at or above `lnum`.
---@param lines string[]
---@param lnum integer 1-indexed cursor line
---@return string|nil nil when there is no def, it is a class method, or it is private/protected
function M.action_at(lines, lnum)
  local action
  local is_hidden_section = false
  local is_hidden_action = false
  for index = 1, math.min(lnum, #lines) do
    local line = lines[index]
    if matches_any(line, HIDDEN_SECTION_PATTERNS) then
      is_hidden_section = true
    end
    local name, receiver_dot = line:match(DEF_PATTERN)
    local is_hidden_def = matches_any(line, HIDDEN_DEF_PATTERNS)
    if is_hidden_def then
      name = line:match("def%s+([%w_]+[?!]?)")
    end
    if name then
      action = receiver_dot ~= "." and name or nil
      is_hidden_action = is_hidden_section or is_hidden_def
    end
  end
  if is_hidden_action then
    return nil
  end
  return action
end

return M
