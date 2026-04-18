# rails-tools.nvim — Đặc tả kỹ thuật hoàn chỉnh

## 1. Tổng quan

**rails-tools.nvim** là một Neovim plugin hỗ trợ phát triển Ruby on Rails, thiết kế theo triết lý **zero-config, discoverable, context-aware**.

- **Ngôn ngữ:** Lua
- **Neovim tối thiểu:** 0.9+
- **Dependencies bắt buộc:** Không có
- **Dependencies tùy chọn:** telescope.nvim, which-key.nvim, toggleterm.nvim
- **Test framework:** plenary.nvim test harness
- **License:** MIT

---

## 2. Triết lý thiết kế

1. **Zero-config:** `require("rails-tools").setup()` không truyền gì vẫn hoạt động đầy đủ.
2. **Single entry point:** Lệnh `:Rails` là điểm truy cập trung tâm.
3. **Discoverable:** Tích hợp Telescope (optional) và Which-Key.
4. **Context-aware:** Tự nhận diện loại file và đề xuất hành động phù hợp.
5. **Convention over configuration:** Theo chuẩn Rails, cho phép override khi cần.

---

## 3. Cấu trúc thư mục

```
rails-tools.nvim/
├── lua/
│   └── rails-tools/
│       ├── init.lua              -- Entry point, setup()
│       ├── config.lua            -- Default config & merge logic
│       ├── commands.lua          -- User commands registration
│       ├── keymaps.lua           -- Keymap registration
│       ├── utils.lua             -- Shared utilities
│       ├── cache.lua             -- Cache layer (routes, schema)
│       ├── detectors/
│       │   ├── init.lua          -- Detector orchestrator
│       │   ├── rails.lua         -- Rails project detection
│       │   ├── rspec.lua         -- RSpec vs Minitest detection
│       │   └── grape.lua         -- Grape API detection
│       ├── core/
│       │   ├── alternate.lua     -- Alternate file navigation
│       │   ├── finder.lua        -- Resource finder
│       │   ├── routes.lua        -- Routes parser & navigator
│       │   ├── generators.lua    -- Rails generators wrapper
│       │   ├── console.lua       -- Rails console integration
│       │   └── runner.lua        -- Rails runner
│       ├── telescope/
│       │   └── init.lua          -- Telescope pickers
│       ├── integrations/
│       │   ├── rspec.lua         -- RSpec runner
│       │   ├── grape.lua         -- Grape API support
│       │   └── test_marker.lua   -- Focus/unfocus test
│       ├── ui/
│       │   ├── menu.lua          -- :Rails menu (vim.ui.select)
│       │   └── terminal.lua      -- Terminal abstraction layer
│       └── health.lua            -- :checkhealth rails-tools
├── plugin/
│   └── rails-tools.lua           -- Auto-load, lazy registration
├── doc/
│   └── rails-tools.txt           -- Vimdoc help
├── tests/
│   ├── minimal_init.lua          -- Minimal config cho test
│   ├── detectors/
│   │   ├── rails_spec.lua
│   │   ├── rspec_spec.lua
│   │   └── grape_spec.lua
│   ├── core/
│   │   ├── alternate_spec.lua
│   │   ├── finder_spec.lua
│   │   ├── routes_spec.lua
│   │   └── generators_spec.lua
│   └── integrations/
│       ├── rspec_spec.lua
│       └── grape_spec.lua
├── Makefile                      -- Test runner, lint
├── README.md
├── LICENSE
└── .github/
    └── workflows/
        └── ci.yml                -- GitHub Actions: test + lint
```

---

## 4. Configuration

### 4.1 Default config

```lua
-- lua/rails-tools/config.lua

local M = {}

M.defaults = {
  -- Bật/tắt từng module
  modules = {
    alternate = true,
    finder = true,
    routes = true,
    console = true,
    runner = true,
    generators = false,   -- Phase 2
    rspec = false,         -- Phase 2
    grape = false,         -- Phase 2
    test_marker = false,   -- Phase 2
  },

  -- Alternate file mappings
  -- Pattern: regex capture group, Replacement: %1 là capture
  alternate = {
    mappings = {
      -- Model <-> Spec
      { pattern = "app/models/(.+).rb$",           target = "spec/models/%1_spec.rb" },
      { pattern = "spec/models/(.+)_spec.rb$",     target = "app/models/%1.rb" },

      -- Controller <-> Request Spec
      { pattern = "app/controllers/(.+)_controller.rb$", target = "spec/requests/%1_spec.rb" },
      { pattern = "spec/requests/(.+)_spec.rb$",         target = "app/controllers/%1_controller.rb" },

      -- Service <-> Spec
      { pattern = "app/services/(.+).rb$",          target = "spec/services/%1_spec.rb" },
      { pattern = "spec/services/(.+)_spec.rb$",    target = "app/services/%1.rb" },

      -- Policy <-> Spec
      { pattern = "app/policies/(.+)_policy.rb$",   target = "spec/policies/%1_policy_spec.rb" },
      { pattern = "spec/policies/(.+)_policy_spec.rb$", target = "app/policies/%1_policy.rb" },

      -- Job <-> Spec
      { pattern = "app/jobs/(.+)_job.rb$",          target = "spec/jobs/%1_job_spec.rb" },
      { pattern = "spec/jobs/(.+)_job_spec.rb$",    target = "app/jobs/%1_job.rb" },

      -- Mailer <-> Spec
      { pattern = "app/mailers/(.+)_mailer.rb$",    target = "spec/mailers/%1_mailer_spec.rb" },
      { pattern = "spec/mailers/(.+)_mailer_spec.rb$", target = "app/mailers/%1_mailer.rb" },

      -- Serializer <-> Spec
      { pattern = "app/serializers/(.+)_serializer.rb$", target = "spec/serializers/%1_serializer_spec.rb" },
      { pattern = "spec/serializers/(.+)_serializer_spec.rb$", target = "app/serializers/%1_serializer.rb" },
    },

    -- User có thể thêm custom mappings
    -- Custom mappings được ưu tiên hơn default
    custom_mappings = {},
  },

  -- Terminal configuration
  terminal = {
    provider = "auto",    -- "auto" | "toggleterm" | "native"
                          -- auto: dùng toggleterm nếu có, fallback native
    direction = "float",  -- "float" | "horizontal" | "vertical"
    float_opts = {
      width = 0.8,        -- % of screen
      height = 0.8,
    },
    size = {
      horizontal = 15,
      vertical = 80,
    },
  },

  -- Finder configuration
  finder = {
    provider = "auto",    -- "auto" | "telescope" | "native"
                          -- auto: dùng telescope nếu có, fallback vim.ui.select
  },

  -- Routes
  routes = {
    cache_ttl = 300,      -- Cache routes 5 phút (giây)
  },

  -- Keymaps
  keymaps = {
    enabled = true,
    prefix = "<leader>r",
  },

  -- Console
  console = {
    command = "rails console", -- Override nếu cần (ví dụ: "bundle exec rails c")
  },

  -- Runner
  runner = {
    command = "rails runner",
  },
}

--- Merge user config với defaults (deep merge)
---@param user_config table|nil
---@return table
function M.setup(user_config)
  M.current = vim.tbl_deep_extend("force", M.defaults, user_config or {})
  return M.current
end

--- Get current config
---@return table
function M.get()
  return M.current or M.defaults
end

return M
```

### 4.2 Ví dụ sử dụng

```lua
-- Minimal: zero-config
require("rails-tools").setup()

-- Custom: bật Grape, đổi terminal
require("rails-tools").setup({
  modules = {
    grape = true,
    rspec = true,
  },
  terminal = {
    direction = "horizontal",
  },
  alternate = {
    custom_mappings = {
      { pattern = "app/forms/(.+)_form.rb$", target = "spec/forms/%1_form_spec.rb" },
      { pattern = "spec/forms/(.+)_form_spec.rb$", target = "app/forms/%1_form.rb" },
    },
  },
})
```

---

## 5. Module specs

### 5.1 Rails Detector (`detectors/rails.lua`)

**Mục đích:** Xác định thư mục hiện tại có phải Rails project không.

**Logic:**

```
is_rails_project() -> boolean
  1. Tìm root directory bằng cách đi lên từ cwd
  2. Kiểm tra tồn tại: Gemfile AND (bin/rails OR script/rails)
  3. Cache kết quả theo root path
  4. Return true/false
```

**API:**

```lua
local detector = require("rails-tools.detectors.rails")

detector.detect()          -- -> { is_rails = true, root = "/path/to/project" } | nil
detector.root()            -- -> "/path/to/project" | nil
detector.is_rails()        -- -> boolean
```

**Kiểm tra bổ sung (lazy, chỉ khi cần):**

- `Gemfile` chứa gem `'rails'` → xác nhận chắc chắn
- Tồn tại `config/application.rb` → xác nhận chắc chắn
- Tồn tại `config/routes.rb` → xác nhận chắc chắn

**Edge cases:**

- Monorepo: mỗi subfolder có Gemfile riêng → detect từ file đang mở, không phải cwd
- Engine: có `lib/engine_name/engine.rb` → detect là engine, không phải full app
- Không phải Rails → tất cả commands bị disable, hiển thị warning một lần

---

### 5.2 RSpec Detector (`detectors/rspec.lua`)

**Mục đích:** Xác định project dùng RSpec hay Minitest.

**Logic:**

```
detect() -> "rspec" | "minitest" | nil
  1. Kiểm tra tồn tại: spec/ directory → "rspec"
  2. Kiểm tra tồn tại: test/ directory → "minitest"
  3. Nếu cả hai tồn tại → kiểm tra Gemfile: gem 'rspec-rails' → "rspec"
  4. Fallback: nil
```

**API:**

```lua
local rspec_detector = require("rails-tools.detectors.rspec")

rspec_detector.detect()        -- -> "rspec" | "minitest" | nil
rspec_detector.is_rspec()      -- -> boolean
rspec_detector.is_minitest()   -- -> boolean
```

---

### 5.3 Grape Detector (`detectors/grape.lua`)

**Mục đích:** Xác định project có dùng Grape API không.

**Logic:**

```
detect() -> boolean
  1. Kiểm tra tồn tại: app/api/ directory
  2. Kiểm tra Gemfile chứa gem 'grape'
  3. Cả hai đều đúng → true
```

---

### 5.4 Alternate File (`core/alternate.lua`)

**Mục đích:** Chuyển đổi giữa file implementation và file test/spec tương ứng.

**API:**

```lua
local alternate = require("rails-tools.core.alternate")

alternate.open()               -- Mở alternate file của file hiện tại
alternate.get(filepath)        -- -> string|nil: trả về path alternate, không mở
```

**Logic:**

```
open()
  1. Lấy relative path của file hiện tại (so với Rails root)
  2. Duyệt custom_mappings trước, rồi default mappings
  3. Với mỗi mapping: match pattern → tạo target path
  4. Nếu target file tồn tại → mở
  5. Nếu target file KHÔNG tồn tại → hỏi user có muốn tạo không (vim.ui.input)
  6. Nếu không match mapping nào → thông báo "No alternate file found"
```

**Edge cases:**

- File nằm ngoài Rails root → bỏ qua
- Nested namespaces: `app/models/admin/user.rb` → `spec/models/admin/user_spec.rb`
- File không có mapping → thông báo rõ ràng, không crash

---

### 5.5 Finder (`core/finder.lua`)

**Mục đích:** Tìm kiếm Rails resources bằng Telescope hoặc vim.ui.select.

**API:**

```lua
local finder = require("rails-tools.core.finder")

finder.find("models")         -- Mở picker với tất cả models
finder.find("controllers")    -- Mở picker với tất cả controllers
finder.find("views")          -- Mở picker với tất cả views
finder.find("specs")          -- Mở picker với tất cả specs
finder.find("services")       -- Mở picker với tất cả services
finder.find("jobs")           -- Mở picker với tất cả jobs
finder.find("all")            -- Mở picker với tất cả Rails files
```

**Resource paths (convention):**

```lua
local resource_paths = {
  models      = "app/models",
  controllers = "app/controllers",
  views       = "app/views",
  services    = "app/services",
  policies    = "app/policies",
  jobs        = "app/jobs",
  mailers     = "app/mailers",
  serializers = "app/serializers",
  specs       = "spec",
  factories   = "spec/factories",
}
```

**Logic:**

```
find(resource_type)
  1. Xác định directory từ resource_paths
  2. Scan tất cả .rb files (recursive)
  3. Nếu Telescope available → telescope picker
  4. Nếu không → vim.ui.select
  5. User chọn → mở file
```

---

### 5.6 Routes Navigator (`core/routes.lua`)

**Mục đích:** Parse và hiển thị Rails routes, cho phép nhảy đến controller#action.

**API:**

```lua
local routes = require("rails-tools.core.routes")

routes.show()          -- Hiển thị routes trong picker
routes.refresh()       -- Xóa cache, parse lại
routes.goto_action()   -- Nhảy đến controller#action từ route đang chọn
```

**Logic:**

```
show()
  1. Kiểm tra cache (TTL từ config)
  2. Nếu cache hết hạn hoặc chưa có:
     - Chạy `bin/rails routes --expanded` (async, dùng vim.fn.jobstart)
     - Parse output thành list: { method, path, controller_action, name }
     - Lưu cache
  3. Hiển thị trong picker (Telescope hoặc vim.ui.select)
  4. Khi user chọn route → parse controller#action → mở file tại method tương ứng
```

**Parse format:**

```
GET    /users          users#index
POST   /users          users#create
GET    /users/:id      users#show
```

→ Chuyển `users#index` thành `app/controllers/users_controller.rb` và nhảy đến method `def index`.

**Edge cases:**

- Namespaced routes: `admin/users#index` → `app/controllers/admin/users_controller.rb`
- `rails routes` chậm trên project lớn → chạy async, hiển thị loading
- `rails routes` fail → hiển thị error message rõ ràng

---

### 5.7 Console (`core/console.lua`)

**Mục đích:** Mở Rails console trong terminal tích hợp.

**API:**

```lua
local console = require("rails-tools.core.console")

console.open()         -- Mở rails console
console.toggle()       -- Toggle console window
```

**Logic:**

```
open()
  1. Lấy command từ config (default: "rails console")
  2. Mở terminal qua ui/terminal.lua
  3. Chạy command
```

---

### 5.8 Runner (`core/runner.lua`)

**Mục đích:** Chạy Rails runner cho code snippets nhanh.

**API:**

```lua
local runner = require("rails-tools.core.runner")

runner.run(code)             -- Chạy code string: runner.run("User.count")
runner.run_prompt()          -- Mở input prompt, chạy code user nhập
runner.run_visual()          -- Chạy visual selection
```

---

### 5.9 Terminal Abstraction (`ui/terminal.lua`)

**Mục đích:** Abstract layer cho terminal, hỗ trợ toggleterm và native.

**API:**

```lua
local terminal = require("rails-tools.ui.terminal")

terminal.open(cmd, opts)     -- Mở terminal và chạy cmd
terminal.toggle()            -- Toggle terminal window
terminal.send(text)          -- Gửi text vào terminal đang mở
```

**Logic:**

```
open(cmd, opts)
  1. Kiểm tra provider config
  2. Nếu "auto":
     - pcall(require, "toggleterm") thành công → dùng toggleterm
     - Thất bại → dùng native
  3. Nếu "toggleterm" → dùng toggleterm API
  4. Nếu "native":
     - direction == "float" → vim.api.nvim_open_win (floating)
     - direction == "horizontal" → botright split
     - direction == "vertical" → botright vsplit
     - vim.fn.termopen(cmd)
```

---

### 5.10 Menu (`ui/menu.lua`)

**Mục đích:** Menu trung tâm cho lệnh `:Rails`.

**API:**

```lua
local menu = require("rails-tools.ui.menu")

menu.open()     -- Hiển thị menu chính
```

**Menu items (dynamic dựa trên modules enabled):**

```
Rails Tools
───────────
Alternate File         (luôn hiển thị)
Find Resource          (luôn hiển thị)
View Routes            (nếu modules.routes)
Open Console           (nếu modules.console)
Run Code               (nếu modules.runner)
Run Generator          (nếu modules.generators)
Run Nearest Spec       (nếu modules.rspec)
Run Spec File          (nếu modules.rspec)
Grape Endpoints        (nếu modules.grape)
```

---

## 6. User Commands

```lua
-- Luôn available
:Rails                    -- Menu trung tâm
:RailsAlternate           -- Mở alternate file
:RailsFind {type}         -- Tìm resource (models, controllers, ...)

-- Theo module
:RailsRoutes              -- Routes navigator (modules.routes)
:RailsConsole             -- Mở console (modules.console)
:RailsRunner {code}       -- Chạy code (modules.runner)
:RailsGenerate {args}     -- Chạy generator (modules.generators)
:RailsSpecNearest         -- Chạy spec gần nhất (modules.rspec)
:RailsSpecFile            -- Chạy spec file hiện tại (modules.rspec)
:RailsSpecLast            -- Chạy lại spec cuối (modules.rspec)
:RailsGrapeRoutes         -- Grape routes (modules.grape)
```

---

## 7. Keymaps (mặc định, tắt được)

```lua
-- Prefix: <leader>r
<leader>rr    :Rails                 -- Menu
<leader>ra    :RailsAlternate        -- Alternate file
<leader>rf    :RailsFind             -- Find resource
<leader>ro    :RailsRoutes           -- Routes
<leader>rc    :RailsConsole          -- Console
<leader>rx    :RailsRunner           -- Runner (prompt)

-- Phase 2 (khi module enabled)
<leader>rs    :RailsSpecNearest      -- Nearest spec
<leader>rS    :RailsSpecFile         -- Spec file
<leader>rg    :RailsGenerate         -- Generator
```

---

## 8. Telescope Integration

Khi telescope.nvim có sẵn, các picker tự động dùng Telescope.

```vim
:Telescope rails models
:Telescope rails controllers
:Telescope rails views
:Telescope rails services
:Telescope rails specs
:Telescope rails routes
:Telescope rails grape          " Phase 2
```

Khi không có Telescope → tất cả fallback về `vim.ui.select`.

---

## 9. Health Check

```vim
:checkhealth rails-tools
```

**Output:**

```
rails-tools: require("rails-tools.health").check()
========================================
## Environment
  - OK: Neovim >= 0.9
  - OK: Rails project detected at /path/to/project
  - OK: Ruby 3.2.0
  - OK: Rails 7.1.0
  - WARNING: telescope.nvim not found (using vim.ui.select fallback)
  - OK: toggleterm.nvim found

## Project
  - OK: Gemfile found
  - OK: bin/rails found
  - OK: Test framework: rspec
  - OK: Grape API detected
  - WARNING: Approved migrations (3)

## Modules
  - OK: alternate (enabled)
  - OK: finder (enabled)
  - OK: routes (enabled)
  - DISABLED: rspec
  - DISABLED: grape
```

---

## 10. Error Handling

**Nguyên tắc:**

1. **Không bao giờ crash Neovim.** Mọi lỗi đều được bắt bằng `pcall`.
2. **Thông báo rõ ràng.** Dùng `vim.notify` với level phù hợp (INFO, WARN, ERROR).
3. **Graceful degradation.** Nếu một module lỗi, các module khác vẫn hoạt động.
4. **Không phải Rails project → disable im lặng.** Chỉ thông báo một lần khi user gọi command.

```lua
-- Pattern chuẩn cho mọi command
local function safe_call(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    vim.notify("[rails-tools] " .. tostring(err), vim.log.levels.ERROR)
  end
end
```

---

## 11. Caching Strategy

**Mục đích:** Tránh chạy lại `rails routes` hoặc scan file system liên tục.

```lua
-- lua/rails-tools/cache.lua

local M = {}
local _cache = {}

--- Set cache với TTL
---@param key string
---@param value any
---@param ttl number|nil  TTL tính bằng giây, nil = không hết hạn
function M.set(key, value, ttl)
  _cache[key] = {
    value = value,
    expires_at = ttl and (os.time() + ttl) or nil,
  }
end

--- Get cache
---@param key string
---@return any|nil
function M.get(key)
  local entry = _cache[key]
  if not entry then return nil end
  if entry.expires_at and os.time() > entry.expires_at then
    _cache[key] = nil
    return nil
  end
  return entry.value
end

--- Xóa cache
---@param key string|nil  nil = xóa tất cả
function M.clear(key)
  if key then
    _cache[key] = nil
  else
    _cache = {}
  end
end

return M
```

**Cái gì cache:**

| Dữ liệu | TTL | Invalidation |
|---|---|---|
| Rails root path | Không hết hạn | Khi đổi cwd |
| Detector results | Không hết hạn | Khi đổi cwd |
| Routes | 5 phút (configurable) | `:RailsRoutes!` force refresh |
| File list (finder) | 30 giây | Tự động |

---

## 12. Async Strategy

**Nguyên tắc:** Mọi lệnh shell đều chạy async để không block UI.

```lua
-- Pattern chuẩn cho async shell command
local function async_cmd(cmd, on_done)
  local output = {}
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(output, data)
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        on_done(output, exit_code)
      end)
    end,
  })
end
```

**Commands chạy async:**

- `rails routes`
- `rails console` (interactive, trong terminal)
- `rails runner`
- `rails generate`
- RSpec runner

---

## 13. Roadmap

### Phase 1 — MVP (v0.1 → v0.3)

| Version | Tính năng | Module |
|---|---|---|
| v0.1 | Rails Detection | `detectors/rails.lua` |
| v0.1 | RSpec/Minitest Detection | `detectors/rspec.lua` |
| v0.1 | Alternate File | `core/alternate.lua` |
| v0.1 | Config system | `config.lua` |
| v0.1 | Health check | `health.lua` |
| v0.2 | Resource Finder | `core/finder.lua` |
| v0.2 | Telescope pickers | `telescope/init.lua` |
| v0.2 | Menu `:Rails` | `ui/menu.lua` |
| v0.2 | Keymaps | `keymaps.lua` |
| v0.3 | Routes Navigator | `core/routes.lua` |
| v0.3 | Console | `core/console.lua` |
| v0.3 | Runner | `core/runner.lua` |
| v0.3 | Terminal abstraction | `ui/terminal.lua` |

### Phase 2 — Mở rộng (v0.4 → v0.7)

| Version | Tính năng | Module |
|---|---|---|
| v0.4 | RSpec Runner (nearest, file, last) | `integrations/rspec.lua` |
| v0.5 | Generators | `core/generators.lua` |
| v0.6 | Grape API Detection | `detectors/grape.lua` |
| v0.6 | Grape Support | `integrations/grape.lua` |
| v0.7 | Test Marker (focus/unfocus) | `integrations/test_marker.lua` |

### Phase 3 — Polish (v0.8 → v1.0)

| Version | Tính năng |
|---|---|
| v0.8 | Schema Inspector |
| v0.8 | Log Viewer |
| v0.9 | Rails Doctor |
| v1.0 | Documentation hoàn chỉnh, stable release |

### Post v1.0

- Gem Navigator
- Engines & Monorepo support
- Community-driven features

---

## 14. Testing Strategy

**Framework:** plenary.nvim test harness

**Chạy test:**

```bash
make test                    # Chạy tất cả
make test FILE=tests/core/alternate_spec.lua  # Chạy một file
```

**Makefile:**

```makefile
TESTS_DIR := tests
MINIMAL_INIT := tests/minimal_init.lua

test:
	nvim --headless -u $(MINIMAL_INIT) \
		-c "PlenaryBustedDirectory $(TESTS_DIR) { minimal_init = '$(MINIMAL_INIT)' }"

test-file:
	nvim --headless -u $(MINIMAL_INIT) \
		-c "PlenaryBustedFile $(FILE) { minimal_init = '$(MINIMAL_INIT)' }"

lint:
	luacheck lua/ tests/

.PHONY: test test-file lint
```

**Ví dụ test:**

```lua
-- tests/detectors/rails_spec.lua
local detector = require("rails-tools.detectors.rails")

describe("rails detector", function()
  it("detects rails project with Gemfile and bin/rails", function()
    -- Setup: tạo temp directory với Gemfile và bin/rails
    -- ...
    local result = detector.detect()
    assert.is_true(result.is_rails)
    assert.is_not_nil(result.root)
  end)

  it("returns nil for non-rails project", function()
    local result = detector.detect()
    assert.is_nil(result)
  end)
end)
```

```lua
-- tests/core/alternate_spec.lua
local alternate = require("rails-tools.core.alternate")

describe("alternate file", function()
  it("maps model to spec", function()
    local result = alternate.get("app/models/user.rb")
    assert.equals("spec/models/user_spec.rb", result)
  end)

  it("maps spec to model", function()
    local result = alternate.get("spec/models/user_spec.rb")
    assert.equals("app/models/user.rb", result)
  end)

  it("handles nested namespaces", function()
    local result = alternate.get("app/models/admin/user.rb")
    assert.equals("spec/models/admin/user_spec.rb", result)
  end)

  it("maps controller to request spec", function()
    local result = alternate.get("app/controllers/users_controller.rb")
    assert.equals("spec/requests/users_spec.rb", result)
  end)

  it("returns nil for unknown file", function()
    local result = alternate.get("README.md")
    assert.is_nil(result)
  end)

  it("uses custom mappings with higher priority", function()
    -- Setup custom mapping
    local config = require("rails-tools.config")
    config.setup({
      alternate = {
        custom_mappings = {
          { pattern = "app/forms/(.+)_form.rb$", target = "spec/forms/%1_form_spec.rb" },
        },
      },
    })

    local result = alternate.get("app/forms/registration_form.rb")
    assert.equals("spec/forms/registration_form_spec.rb", result)
  end)
end)
```

---

## 15. CI/CD

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        neovim-version: ['v0.9.5', 'v0.10.0', 'nightly']
    steps:
      - uses: actions/checkout@v4
      - uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
          version: ${{ matrix.neovim-version }}

      - name: Install plenary.nvim
        run: |
          git clone --depth 1 https://github.com/nvim-lua/plenary.nvim \
            ~/.local/share/nvim/site/pack/test/start/plenary.nvim

      - name: Run tests
        run: make test

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: JohnnyMorganz/stylua-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          args: --check lua/ tests/
```

---

## 16. Plugin Entry Point

```lua
-- lua/rails-tools/init.lua

local M = {}

---@param user_config table|nil
function M.setup(user_config)
  local config = require("rails-tools.config")
  config.setup(user_config)

  -- Detect Rails project
  local detector = require("rails-tools.detectors.rails")
  if not detector.is_rails() then
    -- Không phải Rails project, chỉ đăng ký command :Rails để thông báo
    vim.api.nvim_create_user_command("Rails", function()
      vim.notify("[rails-tools] Not a Rails project", vim.log.levels.WARN)
    end, {})
    return
  end

  -- Register commands
  require("rails-tools.commands").setup()

  -- Register keymaps (nếu enabled)
  if config.get().keymaps.enabled then
    require("rails-tools.keymaps").setup()
  end

  -- Register Telescope extension (nếu available)
  local has_telescope = pcall(require, "telescope")
  if has_telescope then
    require("telescope").register_extension({
      exports = require("rails-tools.telescope").exports,
    })
  end
end

return M
```

---

## 17. Ví dụ lazy.nvim Installation

```lua
-- Minimal
{
  "your-username/rails-tools.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",           -- Required (test + async)
  },
  ft = "ruby",                          -- Lazy load khi mở file Ruby
  config = function()
    require("rails-tools").setup()
  end,
}

-- Full featured
{
  "your-username/rails-tools.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",    -- Optional: better picker
    "akinsho/toggleterm.nvim",          -- Optional: better terminal
    "folke/which-key.nvim",             -- Optional: keymap hints
  },
  ft = "ruby",
  config = function()
    require("rails-tools").setup({
      modules = {
        rspec = true,
        grape = true,
      },
    })
  end,
}
```
