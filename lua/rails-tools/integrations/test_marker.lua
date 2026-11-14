local config = require("rails-tools.config")

local M = {}

local FOCUS_MARKER = "f"
local RSPEC_PREFIX = "RSpec."
local BLOCK_KEYWORDS = { "it", "describe", "context" }
local BLOCK_ARGUMENT_START = "[%w_'\"%(:{%[%%@]"

---@class RailsToolsSpecBlock
---@field line integer 1-based buffer line of the block
---@field keyword_col integer 0-based column where the keyword (or its focus marker) starts
---@field focused boolean

---@param rest string text right after the keyword
---@return boolean
local function starts_block_call(rest)
  if rest == "" or rest:match("^[({]") then
    return true
  end

  local first_argument_char = rest:match("^%s+(.)")
  return first_argument_char ~= nil and first_argument_char:match(BLOCK_ARGUMENT_START) ~= nil
end

---@param text string
---@param col integer 1-based column where a keyword may start
---@return boolean|nil focused, nil when no block keyword starts at col
local function match_keyword(text, col)
  local focused = text:sub(col, col) == FOCUS_MARKER
  local keyword_start = focused and col + 1 or col

  for _, keyword in ipairs(BLOCK_KEYWORDS) do
    local keyword_end = keyword_start + #keyword - 1
    if text:sub(keyword_start, keyword_end) == keyword and starts_block_call(text:sub(keyword_end + 1)) then
      return focused
    end
  end

  return nil
end

---@param text string
---@param line integer
---@return RailsToolsSpecBlock|nil
local function parse_block_line(text, line)
  local col = #text:match("^%s*") + 1
  if text:sub(col, col + #RSPEC_PREFIX - 1) == RSPEC_PREFIX then
    col = col + #RSPEC_PREFIX
  end

  local focused = match_keyword(text, col)
  if focused == nil then
    return nil
  end

  return { line = line, keyword_col = col - 1, focused = focused }
end

---@return boolean
local function is_enabled()
  if config.get().modules.test_marker then
    return true
  end

  vim.notify("Rails: test marker is disabled, set modules.test_marker = true", vim.log.levels.WARN)
  return false
end

---@return RailsToolsSpecBlock|nil
local function nearest_block()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, cursor_line, false)
  for line = cursor_line, 1, -1 do
    local block = parse_block_line(lines[line], line)
    if block then
      return block
    end
  end

  vim.notify("Rails: no it/describe/context block at or above the cursor", vim.log.levels.WARN)
  return nil
end

---@param block RailsToolsSpecBlock
---@param focused boolean
local function set_focus(block, focused)
  local row = block.line - 1
  local marker_end = focused and block.keyword_col or block.keyword_col + #FOCUS_MARKER
  vim.api.nvim_buf_set_text(0, row, block.keyword_col, row, marker_end, { focused and FOCUS_MARKER or "" })
end

---Check whether the nearest it/describe/context block at or above the cursor is focused
---@return boolean|nil focused, nil when no block is found or the module is disabled
function M.is_focused()
  if not is_enabled() then
    return nil
  end

  local block = nearest_block()
  if not block then
    return nil
  end

  return block.focused
end

---Focus the nearest block: it -> fit, describe -> fdescribe, context -> fcontext
---@return boolean changed
function M.focus()
  if not is_enabled() then
    return false
  end

  local block = nearest_block()
  if not block or block.focused then
    return false
  end

  set_focus(block, true)
  return true
end

---Remove the focus marker from the nearest block: fit -> it, fdescribe -> describe, fcontext -> context
---@return boolean changed
function M.unfocus()
  if not is_enabled() then
    return false
  end

  local block = nearest_block()
  if not block or not block.focused then
    return false
  end

  set_focus(block, false)
  return true
end

---Focus the nearest block, or unfocus it when it is already focused
---@return boolean changed
function M.toggle()
  if not is_enabled() then
    return false
  end

  local block = nearest_block()
  if not block then
    return false
  end

  set_focus(block, not block.focused)
  return true
end

return M
