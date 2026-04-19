local M = {}

-- Default mappings. Custom mappings can be provided by a user config that
-- returns a table `mappings` and should be placed before these defaults.
M.mappings = {
  -- Primary mappings (app -> spec)
  { from = [[^app/models/(.+)%.rb$]], to = "spec/models/%1_spec.rb" },
  { from = [[^app/controllers/(.+)_controller%.rb$]], to = "spec/requests/%1_spec.rb" },
  { from = [[^app/services/(.+)%.rb$]], to = "spec/services/%1_spec.rb" },
  { from = [[^app/policies/(.+)%.rb$]], to = "spec/policies/%1_spec.rb" },
  { from = [[^app/jobs/(.+)%.rb$]], to = "spec/jobs/%1_spec.rb" },
  { from = [[^app/mailers/(.+)%.rb$]], to = "spec/mailers/%1_spec.rb" },
  { from = [[^app/serializers/(.+)%.rb$]], to = "spec/serializers/%1_spec.rb" },

  -- Reverse mappings (spec -> app)
  { from = [[^spec/models/(.+)_spec%.rb$]], to = "app/models/%1.rb" },
  { from = [[^spec/requests/(.+)_spec%.rb$]], to = "app/controllers/%1_controller.rb" },
  { from = [[^spec/services/(.+)_spec%.rb$]], to = "app/services/%1.rb" },
  { from = [[^spec/policies/(.+)_spec%.rb$]], to = "app/policies/%1.rb" },
  { from = [[^spec/jobs/(.+)_spec%.rb$]], to = "app/jobs/%1.rb" },
  { from = [[^spec/mailers/(.+)_spec%.rb$]], to = "app/mailers/%1.rb" },
  { from = [[^spec/serializers/(.+)_spec%.rb$]], to = "app/serializers/%1.rb" },
}

return M
