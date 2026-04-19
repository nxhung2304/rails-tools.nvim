## **Status:**
- Review: Approved
- PR: Draft
- GitHub Issue: #26

## Metadata
- **Title:** Test Rails Application
- **Phase:** Infrastructure
- **Type:** Testing & Development Environment

---

## Description
Create a minimal Rails application in `test-app/` directory for testing and demonstrating the plugin features during development.

This test app serves as:
- **Development sandbox** - Test features quickly without creating projects
- **Documentation examples** - Real Rails code for reference
- **E2E testing** - Automated integration tests
- **Manual testing** - Easy testing for contributors and users

---

## Design

### Directory Structure
```
test-app/
├── app/
│   ├── models/
│   │   ├── user.rb
│   │   ├── admin/
│   │   │   └── user.rb          # Nested namespace example
│   │   └── concern/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── users_controller.rb
│   │   └── admin/
│   │       └── users_controller.rb
│   ├── services/
│   │   ├── payment_processor.rb
│   │   └── user_service.rb
│   ├── jobs/
│   │   └── cleanup_job.rb
│   ├── mailers/
│   │   └── user_mailer.rb
│   ├── policies/
│   │   └── user_policy.rb
│   └── serializers/
│       └── user_serializer.rb
├── spec/                          # RSpec tests
│   ├── models/
│   │   ├── user_spec.rb
│   │   └── admin/
│   │       └── user_spec.rb
│   ├── requests/
│   │   └── users_spec.rb
│   ├── services/
│   ├── jobs/
│   ├── mailers/
│   ├── policies/
│   └── serializers/
├── test/                          # MiniTest tests
│   ├── models/
│   │   ├── user_test.rb
│   │   └── admin/
│   │       └── user_test.rb
│   ├── controllers/
│   │   └── users_controller_test.rb
│   ├── services/
│   ├── jobs/
│   ├── mailers/
│   ├── policies/
│   └── serializers/
├── config/
│   ├── routes.rb
│   └── application.rb
├── Gemfile
├── README.md                      # Testing instructions
└── bin/
    └── rails
```

### README.md Contents
```markdown
# Rails Tools Test App

Minimal Rails application for testing rails-tools.nvim plugin.

## Purpose
- Test alternate file navigation
- Test resource finder
- Test routes navigator
- Test all plugin features

## Usage

### Quick Test
```bash
# From plugin root
cd test-app
nvim app/models/user.rb

# Test alternate file
:lua require("rails-tools.core.alternate").open()
```

### Test Specific Features
- **Alternate File:** Open any file in app/, then run `:Rails alternate`
- **Finder:** `:Rails find models` or `:Telescope rails models`
- **Routes:** `:Rails routes` or `:Telescope rails routes`

## Project Structure
- Both RSpec (spec/) and MiniTest (test/) enabled
- Nested namespaces (admin/*)
- All major Rails file types covered
```

---

## Acceptance Criteria
- [ ] Rails app structure created in `test-app/`
- [ ] Has both `spec/` and `test/` directories (RSpec + MiniTest)
- [ ] Contains sample files for all Rails types
- [ ] Includes nested namespace examples (admin/*)
- [ ] Has proper Gemfile with rails, rspec-rails
- [ ] README.md with testing instructions
- [ ] Can be used to test all plugin features
- [ ] All files have minimal but realistic content

---

## Implementation Checklist
- [ ] Create `test-app/` directory structure
- [ ] Set up Rails app skeleton (or create manually for minimal setup)
- [ ] Add sample model files (user.rb, admin/user.rb)
- [ ] Add sample controller files
- [ ] Add sample service, job, mailer, policy, serializer files
- [ ] Create matching spec files for RSpec
- [ ] Create matching test files for MiniTest
- [ ] Write Gemfile with required gems
- [ ] Create config/routes.rb with sample routes
- [ ] Write README.md with usage instructions
- [ ] Test alternate file navigation works
- [ ] Test resource finder works

---

## Notes
- Keep it minimal - don't need full Rails stack
- Can be created manually or use `rails new test-app --minimal`
- All files should have simple but realistic content
- This is NOT a production app, purely for testing
- Should be gitignored or kept minimal in repo
- Can be used for manual testing during development
- Future: Add automated E2E tests using this app
