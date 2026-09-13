local annotate = require("rails-tools.core.annotate")
local rails = require("rails-tools.detectors.rails")
local cache_module = require("rails-tools.cache")

local M = {}
local resolved_cache = cache_module.new(300)

---@class SchemaColumn
---@field type string e.g. "string", "integer"
---@field signature string everything after `t.<type>`, e.g. `"email", null: false`
---@field lnum integer 1-indexed line number within db/schema.rb

---@class SchemaTable
---@field columns table<string, SchemaColumn>
---@field indexes string[] raw `add_index` / `t.index` lines, trimmed
---@field lnum integer 1-indexed line number of the `create_table` call

---Parse a `db/schema.rb` file's contents.
---@param lines string[]
---@return table<string, SchemaTable> keyed by table name
function M.parse(lines)
  local tables = {}
  local current_table

  for lnum, line in ipairs(lines) do
    local table_name = line:match('create_table%s+["\']([%w_]+)["\']')
    if table_name then
      current_table = { columns = {}, indexes = {}, lnum = lnum }
      tables[table_name] = current_table
    elseif current_table then
      if line:match("^%s*end%s*$") then
        current_table = nil
      else
        local col_type, col_name, rest = line:match('^%s*t%.(%w+)%s+["\']([%w_]+)["\']%s*(.-)%s*$')
        if col_type then
          rest = rest:gsub("^,%s*", "")
          current_table.columns[col_name] = {
            type = col_type,
            signature = vim.trim(rest),
            lnum = lnum,
          }
        elseif line:match("add_index") or line:match("t%.index") then
          table.insert(current_table.indexes, vim.trim(line))
        end
      end
    end
  end

  return tables
end

---@param root string Rails project root
---@return table<string, SchemaTable>|nil nil if db/schema.rb doesn't exist
function M.load(root)
  local path = root .. "/db/schema.rb"
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return M.parse(lines)
end

---@class ResolvedColumn
---@field signature string annotate's signature when available, else `:type rest` derived from db/schema.rb
---@field location {file: string, lnum: integer, col: integer} where `gd` should jump

---@class ResolvedModel
---@field table_name string|nil
---@field columns table<string, ResolvedColumn>

---@class ResolvedSchema
---@field models table<string, ResolvedModel> keyed by camelized model name
---@field known_models table<string, boolean> every model found under app/models, annotated or not

---@param ann AnnotatedModel
---@param schema_table SchemaTable|nil
---@param schema_path string
---@return table<string, ResolvedColumn>
local function merge_columns(ann, schema_table, schema_path)
  local columns = {}

  if schema_table then
    for col_name, schema_col in pairs(schema_table.columns) do
      local ann_col = ann.columns[col_name]
      local signature = schema_col.type and (":" .. schema_col.type) or ""
      if schema_col.signature ~= "" then
        signature = signature .. " " .. schema_col.signature
      end
      columns[col_name] = {
        signature = (ann_col and ann_col.signature) or signature,
        location = ann_col and { file = ann.file, lnum = ann_col.lnum, col = ann_col.col }
          or { file = schema_path, lnum = schema_col.lnum, col = 0 },
      }
    end
  end

  -- Columns the annotate block knows about but db/schema.rb doesn't emit as
  -- an explicit `t.*` line (implicit `id`, or db/schema.rb missing/stale).
  for col_name, ann_col in pairs(ann.columns) do
    if not columns[col_name] then
      columns[col_name] = {
        signature = ann_col.signature,
        location = { file = ann.file, lnum = ann_col.lnum, col = ann_col.col },
      }
    end
  end

  return columns
end

---@param root string
---@return ResolvedSchema
local function build(root)
  local schema_tables = M.load(root) or {}
  local annotated_models = annotate.scan(root)
  local schema_path = root .. "/db/schema.rb"

  local models = {}
  local known_models = {}

  for model_name, ann in pairs(annotated_models) do
    known_models[model_name] = true
    local schema_table = ann.table_name and schema_tables[ann.table_name]
    models[model_name] = {
      table_name = ann.table_name,
      columns = merge_columns(ann, schema_table, schema_path),
    }
  end

  return { models = models, known_models = known_models }
end

---Resolve the merged schema+annotate data for a Rails project, cached per
---root (TTL: 300s). This is the API hover/cmp/gd are built on.
---@param root? string defaults to the detected Rails root
---@return ResolvedSchema|nil nil when no Rails root can be determined
function M.resolve(root)
  root = root or rails.root()
  if not root then
    return nil
  end
  return resolved_cache:get(root, function()
    return build(root)
  end)
end

---@param root? string defaults to the detected Rails root
function M.invalidate(root)
  root = root or rails.root()
  if root then
    resolved_cache:invalidate(root)
  end
end

return M
