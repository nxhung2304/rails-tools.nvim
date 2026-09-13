local M = {}

---@type table<string, table[]>
local built_in_mappings = {
  rspec = {
    { from = [[^app/models/(.+)%.rb$]], to = "spec/models/%1_spec.rb" },
    { from = [[^app/controllers/(.+)_controller%.rb$]], to = "spec/requests/%1_spec.rb" },
    { from = [[^app/services/(.+)%.rb$]], to = "spec/services/%1_spec.rb" },
    { from = [[^app/policies/(.+)%.rb$]], to = "spec/policies/%1_spec.rb" },
    { from = [[^app/jobs/(.+)%.rb$]], to = "spec/jobs/%1_spec.rb" },
    { from = [[^app/mailers/(.+)%.rb$]], to = "spec/mailers/%1_spec.rb" },
    { from = [[^app/serializers/(.+)%.rb$]], to = "spec/serializers/%1_spec.rb" },
    { from = [[^spec/models/(.+)_spec%.rb$]], to = "app/models/%1.rb" },
    { from = [[^spec/requests/(.+)_spec%.rb$]], to = "app/controllers/%1_controller.rb" },
    { from = [[^spec/services/(.+)_spec%.rb$]], to = "app/services/%1.rb" },
    { from = [[^spec/policies/(.+)_spec%.rb$]], to = "app/policies/%1.rb" },
    { from = [[^spec/jobs/(.+)_spec%.rb$]], to = "app/jobs/%1.rb" },
    { from = [[^spec/mailers/(.+)_spec%.rb$]], to = "app/mailers/%1.rb" },
    { from = [[^spec/serializers/(.+)_spec%.rb$]], to = "app/serializers/%1.rb" },
  },
  minitest = {
    { from = [[^app/models/(.+)%.rb$]], to = "test/models/%1_test.rb" },
    { from = [[^app/controllers/(.+)_controller%.rb$]], to = "test/controllers/%1_controller_test.rb" },
    { from = [[^app/services/(.+)%.rb$]], to = "test/services/%1_test.rb" },
    { from = [[^app/policies/(.+)%.rb$]], to = "test/policies/%1_test.rb" },
    { from = [[^app/jobs/(.+)%.rb$]], to = "test/jobs/%1_test.rb" },
    { from = [[^app/mailers/(.+)%.rb$]], to = "test/mailers/%1_test.rb" },
    { from = [[^app/serializers/(.+)%.rb$]], to = "test/serializers/%1_test.rb" },
    { from = [[^test/models/(.+)_test%.rb$]], to = "app/models/%1.rb" },
    { from = [[^test/controllers/(.+)_controller_test%.rb$]], to = "app/controllers/%1_controller.rb" },
    { from = [[^test/services/(.+)_test%.rb$]], to = "app/services/%1.rb" },
    { from = [[^test/policies/(.+)_test%.rb$]], to = "app/policies/%1.rb" },
    { from = [[^test/jobs/(.+)_test%.rb$]], to = "app/jobs/%1.rb" },
    { from = [[^test/mailers/(.+)_test%.rb$]], to = "app/mailers/%1.rb" },
    { from = [[^test/serializers/(.+)_test%.rb$]], to = "app/serializers/%1.rb" },
  },
}

---@type table
M.defaults = {
  modules = {
    rspec = false,
    generators = false,
    grape = false,
  },
  terminal = {
    provider = "auto",
    direction = "float",
  },
  keymaps = {
    enabled = true,
    prefix = "<leader>r",
  },
  alternate = {
    custom_mappings = {},
  },
}

---@type table|nil
local current

---@param opts table|nil
---@return table
function M.setup(opts)
  current = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return current
end

---@return table
function M.get()
  if not current then
    current = vim.deepcopy(M.defaults)
  end
  return current
end

---@param framework "rspec"|"minitest"
---@return table[]
function M.alternate_mappings(framework)
  local mappings = {}
  for _, m in ipairs(M.get().alternate.custom_mappings) do
    table.insert(mappings, { from = m.from or m.pattern, to = m.to or m.target })
  end
  vim.list_extend(mappings, built_in_mappings[framework] or {})
  return mappings
end

return M
