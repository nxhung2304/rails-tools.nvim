local M = {}

local SPEC_FILE_SUFFIX = "_spec.rb"
local GROUP_PREFIX = "RSpec."
local FOCUSED_PREFIX = "f"

local KEYWORD_PAIRS = {
  { unfocused = "it", is_group = false },
  { unfocused = "specify", is_group = false },
  { unfocused = "example", is_group = false },
  { unfocused = "describe", is_group = true },
  { unfocused = "context", is_group = true },
  { unfocused = "feature", is_group = true },
  { unfocused = "scenario", is_group = false },
}

---@type table<string, {unfocused: string, focused: boolean, is_group: boolean}>
local KEYWORDS = {}
for _, pair in ipairs(KEYWORD_PAIRS) do
  KEYWORDS[pair.unfocused] = { unfocused = pair.unfocused, focused = false, is_group = pair.is_group }
  KEYWORDS[FOCUSED_PREFIX .. pair.unfocused] = { unfocused = pair.unfocused, focused = true, is_group = pair.is_group }
end

---@class RailsToolsMarkerTarget
---@field lnum integer
---@field col integer
---@field keyword string
---@field focused boolean
---@field unfocused_keyword string

---@param text string
---@return {col: integer, keyword: string, info: table}|nil
local function parse_keyword(text)
  local indent_width = #text:match("^%s*")
  local rest = text:sub(indent_width + 1)
  local prefix_width = 0
  local has_group_prefix = vim.startswith(rest, GROUP_PREFIX)
  if has_group_prefix then
    prefix_width = #GROUP_PREFIX
    rest = rest:sub(prefix_width + 1)
  end

  local keyword = rest:match("^[%w_]+")
  local info = keyword and KEYWORDS[keyword]
  if not info or (has_group_prefix and not info.is_group) then
    return nil
  end

  local next_char = rest:sub(#keyword + 1, #keyword + 1)
  if next_char ~= "" and next_char ~= " " and next_char ~= "(" then
    return nil
  end

  return { col = indent_width + prefix_width, keyword = keyword, info = info }
end

---@param text string
---@return boolean
local function is_block_end(text)
  return text:match("^%s*end%s*$") ~= nil or text:match("^%s*end%s*#") ~= nil
end

---@param lnum integer
---@return RailsToolsMarkerTarget|nil
local function target_at(lnum)
  local parsed = parse_keyword(vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1])
  if not parsed then
    return nil
  end

  return {
    lnum = lnum,
    col = parsed.col,
    keyword = parsed.keyword,
    focused = parsed.info.focused,
    unfocused_keyword = parsed.info.unfocused,
  }
end

---@param cursor_lnum integer
---@return RailsToolsMarkerTarget|nil
local function find_target(cursor_lnum)
  local cursor_target = target_at(cursor_lnum)
  if cursor_target then
    return cursor_target
  end

  local cursor_text = vim.api.nvim_buf_get_lines(0, cursor_lnum - 1, cursor_lnum, false)[1]
  local limit = cursor_text:match("^%s*$") and math.huge or vim.fn.indent(cursor_lnum)

  for lnum = cursor_lnum - 1, 1, -1 do
    local text = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
    local indent = vim.fn.indent(lnum)
    if indent <= limit and not text:match("^%s*$") then
      if is_block_end(text) then
        limit = indent - 1
      else
        local target = target_at(lnum)
        if target then
          return target
        end
        if indent < limit then
          limit = indent - 1
        end
      end
    end
  end

  return nil
end

---@return boolean
local function is_spec_buffer()
  local file = vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) or ""
  return vim.endswith(file, SPEC_FILE_SUFFIX)
end

---@param notify_when_missing boolean
---@return RailsToolsMarkerTarget|nil
local function locate_target(notify_when_missing)
  if not is_spec_buffer() then
    if notify_when_missing then
      vim.notify("Rails: not a spec file", vim.log.levels.WARN)
    end
    return nil
  end

  local target = find_target(vim.fn.line("."))
  if not target and notify_when_missing then
    vim.notify("Rails: no example or group at the cursor", vim.log.levels.WARN)
  end

  return target
end

---@param target RailsToolsMarkerTarget
---@param focused boolean
local function write_focus(target, focused)
  local new_keyword = focused and (FOCUSED_PREFIX .. target.unfocused_keyword) or target.unfocused_keyword
  local cursor = vim.api.nvim_win_get_cursor(0)

  local line_index = target.lnum - 1

  vim.api.nvim_buf_set_text(0, line_index, target.col, line_index, target.col + #target.keyword, { new_keyword })

  if cursor[1] == target.lnum and cursor[2] > target.col then
    local shifted_col = cursor[2] + #new_keyword - #target.keyword
    vim.api.nvim_win_set_cursor(0, { cursor[1], shifted_col })
  end
end

---@param decide_focused fun(target: RailsToolsMarkerTarget): boolean
local function change_focus(decide_focused)
  local target = locate_target(true)
  if not target then
    return
  end

  local focused = decide_focused(target)
  if focused == target.focused then
    return
  end

  if not vim.bo.modifiable then
    vim.notify("Rails: buffer is not modifiable", vim.log.levels.WARN)
    return
  end

  write_focus(target, focused)
end

---Tell whether the example or group at the cursor is focused
---@return boolean|nil focused true when focused, false when not, nil when not a spec file or no target
function M.is_focused()
  local target = locate_target(false)
  if not target then
    return nil
  end

  return target.focused
end

---Focus the example or group at the cursor
function M.focus()
  change_focus(function()
    return true
  end)
end

---Unfocus the example or group at the cursor
function M.unfocus()
  change_focus(function()
    return false
  end)
end

---Focus the example or group at the cursor when unfocused, unfocus it when focused
function M.toggle()
  change_focus(function(target)
    return not target.focused
  end)
end

return M
