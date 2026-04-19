# Rails Tools Test App

Minimal Rails application for testing rails-tools.nvim plugin features.

## Purpose

This test application serves as:
- **Development sandbox** - Test plugin features quickly without creating projects
- **Documentation examples** - Real Rails code for reference
- **E2E testing** - Automated integration tests
- **Manual testing** - Easy testing for contributors and users

## Usage

### Quick Test

```bash
# From plugin root
cd test-app
nvim app/models/user.rb

# Test alternate file navigation
:lua require("rails-tools.core.alternate").open()
# Or using the command:
:Rails alternate
```

### Test Specific Features

#### Alternate File Navigation
Open any file in `app/`, then run:
```vim
:Rails alternate
```
This toggles between implementation and test files.

#### Resource Finder
```vim
:Rails find models
:Rails find controllers
:Telescope rails models
```

#### Routes Navigator
```vim
:Rails routes
:Telescope rails routes
```

#### Console
```vim
:Rails console
```

#### Runner
```vim
:Rails runner "User.count"
```

## Project Structure

```
test-app/
├── app/
│   ├── models/           # User model (and nested admin/user.rb)
│   ├── controllers/      # UsersController (and admin/ namespace)
│   ├── services/         # PaymentProcessor, UserService
│   ├── jobs/            # CleanupJob
│   ├── mailers/         # UserMailer
│   ├── policies/        # UserPolicy
│   └── serializers/     # UserSerializer
├── spec/                # RSpec tests (mirrors app/ structure)
├── test/                # MiniTest tests (mirrors app/ structure)
└── config/
    └── routes.rb        # Sample routes including namespace
```

### Key Features

- **Both RSpec and MiniTest** - Test files exist in both `spec/` and `test/`
- **Nested namespaces** - `app/models/admin/user.rb` for testing navigation
- **All major Rails types** - Models, controllers, services, jobs, mailers, policies, serializers
- **Minimal but realistic content** - Files have actual Rails code, not just stubs

## Testing the Plugin

### 1. Alternate File Navigation
```vim
# Open model
:edit app/models/user.rb

# Jump to spec (RSpec)
:Rails alternate

# Jump back
:Rails alternate

# From admin namespace
:edit app/models/admin/user.rb
:Rails alternate  # → spec/models/admin/user_spec.rb
```

### 2. Resource Finder
```vim
:Rails find models
# Opens telescope picker with:
#   - user.rb
#   - admin/user.rb

:Rails find services
# Shows:
#   - payment_processor.rb
#   - user_service.rb
```

### 3. Routes Navigator
```vim
:Rails routes users
# Filters and shows user-related routes
```

## Development Notes

- This is NOT a production Rails app
- Database setup is minimal (can use SQLite for simplicity)
- No actual migrations needed for plugin testing
- Files serve as reference for understanding Rails conventions

## Future Enhancements

- [ ] Add actual database schema.rb
- [ ] Create fixtures/factories for testing
- [ ] Add Grape API endpoints for integration testing
- [ ] Set up automated E2E tests using plenary
