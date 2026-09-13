local model_context = require("rails-tools.core.model_context")

local M = {}

---@class AnnotateColumn
---@field signature string everything after the column name, e.g. `:string not null`
---@field lnum integer 1-indexed line number within the file
---@field col integer 0-indexed byte column of the column name on that line

---@class AnnotateBlock
---@field table_name string|nil from the `# Table name: xxx` line
---@field columns table<string, AnnotateColumn>

---Parse a single model file's `annotate` gem schema comment block.
---@param lines string[]
---@return AnnotateBlock
function M.parse(lines)
  local table_name
  local columns = {}
  local in_block = false

  for lnum, line in ipairs(lines) do
    if line:match("^#%s*==%s*Schema Information") then
      in_block = true
    elseif in_block then
      if not line:match("^#") then
        break
      end

      local found_table_name = line:match("^#%s*Table name:%s*([%w_]+)")
      if found_table_name then
        table_name = found_table_name
      end

      local name, rest = line:match("^#%s+([%w_]+)%s+(:.+)$")
      if name then
        local signature = vim.trim((rest:gsub("%s+", " ")))
        local col_start = line:find(name, 1, true) or 1
        columns[name] = { signature = signature, lnum = lnum, col = col_start - 1 }
      end
    end
  end

  return { table_name = table_name, columns = columns }
end

---@class AnnotatedModel : AnnotateBlock
---@field file string absolute path to the model file

---Scan every `app/models/**/*.rb` file under `root` for annotate blocks.
---@param root string Rails project root
---@return table<string, AnnotatedModel> keyed by camelized model name
function M.scan(root)
  local by_model = {}
  local files = vim.fn.globpath(root, "app/models/**/*.rb", false, true)

  for _, file in ipairs(files) do
    local ok, lines = pcall(vim.fn.readfile, file)
    if ok then
      local model_name = model_context.camelize(vim.fn.fnamemodify(file, ":t:r"))
      local block = M.parse(lines)
      block.file = file
      by_model[model_name] = block
    end
  end

  return by_model
end

return M
