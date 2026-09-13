local M = {}

---Find the identifier under `col` (0-indexed byte offset) on `line`, and
---the receiver identifier immediately before it if preceded by a `.`
---(e.g. `user.status` with the cursor on `status` -> receiver "user",
---word "status"; `status` on its own -> receiver nil, word "status").
---@param line string
---@param col integer 0-indexed byte offset, as returned by `nvim_win_get_cursor`
---@return string|nil receiver
---@return string|nil word
function M.word_and_receiver(line, col)
  local pos = col + 1

  if pos > #line then
    pos = #line
  end
  if pos < 1 or not line:sub(pos, pos):match("[%w_]") then
    if pos > 1 and line:sub(pos - 1, pos - 1):match("[%w_]") then
      pos = pos - 1
    else
      return nil, nil
    end
  end

  local start_idx = pos
  while start_idx > 1 and line:sub(start_idx - 1, start_idx - 1):match("[%w_]") do
    start_idx = start_idx - 1
  end
  local end_idx = pos
  while end_idx < #line and line:sub(end_idx + 1, end_idx + 1):match("[%w_]") do
    end_idx = end_idx + 1
  end

  local word = line:sub(start_idx, end_idx)
  if start_idx <= 1 or line:sub(start_idx - 1, start_idx - 1) ~= "." then
    return nil, word
  end

  local before = line:sub(1, start_idx - 2)
  local receiver = before:match("@?([%a_][%w_]*)$")
  return receiver, word
end

---Thin wrapper around `word_and_receiver` for the current window's cursor.
---@return string|nil receiver
---@return string|nil word
function M.at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return M.word_and_receiver(line, col)
end

return M
