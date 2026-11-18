local MODULES_TO_RELOAD = {
  "rails-tools.core.gf",
  "rails-tools.core.rails_paths",
  "rails-tools.core.routes",
  "rails-tools.config",
  "rails-tools.detectors.rails",
  "rails-tools.cache",
}

local ROUTES_FIXTURE = vim.fn.fnamemodify("tests/fixtures/routes/expanded.txt", ":p")
local JOB_WAIT_MS = 5000

describe("rails-tools.core.gf", function()
  local gf
  local config
  local tmp_dir
  local orig_cwd
  local orig_notify
  local orig_select
  local notifications
  local select_calls
  local select_choice

  local function reload_modules()
    for _, name in ipairs(MODULES_TO_RELOAD) do
      package.loaded[name] = nil
    end
  end

  local function create_file(relative_path, lines)
    local path = tmp_dir .. "/" .. relative_path
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile(lines or {}, path)
  end

  local function resolve(relative_file, line, cursor_text)
    local col = assert(line:find(cursor_text, 1, true), "cursor text not in line") - 1
    return gf.resolve({ root = tmp_dir, file = tmp_dir .. "/" .. relative_file, line = line, col = col })
  end

  local function resolve_text(relative_file, text)
    return gf.resolve_text({ root = tmp_dir, file = tmp_dir .. "/" .. relative_file, text = text })
  end

  local function file_target(paths, extra)
    return vim.tbl_extend("force", { kind = "file", paths = paths }, extra or {})
  end

  local function messages()
    return vim.tbl_map(function(notification)
      return notification.msg
    end, notifications)
  end

  local FILETYPE_BY_EXTENSION = { rb = "ruby", erb = "eruby" }

  local function open_in_buffer(relative_file, lines, cursor)
    create_file(relative_file, lines)
    vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/" .. relative_file))
    vim.bo.filetype = FILETYPE_BY_EXTENSION[vim.fn.fnamemodify(relative_file, ":e")]
    vim.api.nvim_win_set_cursor(0, cursor)
  end

  local function current_file()
    return vim.api.nvim_buf_get_name(0)
  end

  before_each(function()
    orig_cwd = vim.fn.getcwd()
    tmp_dir = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(tmp_dir, "p")
    reload_modules()

    notifications = {}
    orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    select_calls = {}
    select_choice = nil
    orig_select = vim.ui.select
    vim.ui.select = function(items, opts, on_choice)
      table.insert(select_calls, { items = items, opts = opts })
      on_choice(select_choice and select_choice(items) or nil)
    end

    config = require("rails-tools.config")
    config.setup({ modules = { gf = true }, routes = { command = "cat", args = ROUTES_FIXTURE } })
    gf = require("rails-tools.core.gf")

    create_file("Gemfile")
    create_file("bin/rails")
    vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.ui.select = orig_select
    vim.cmd("silent! %bwipeout!")
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_dir, "rf")
    pcall(vim.api.nvim_del_augroup_by_name, "rails_tools_gf")
    reload_modules()
  end)

  describe("resolve() partials", function()
    it("resolves a partial path with a folder", function()
      create_file("app/views/shared/_header.html.erb")

      local target = resolve("app/views/users/index.html.erb", '<%= render "shared/header" %>', "header")

      assert.are.same(file_target({ "app/views/shared/_header.html.erb" }), target)
    end)

    it("resolves a partial name from the current view folder", function()
      create_file("app/views/users/_user.html.erb")

      local target = resolve(
        "app/views/users/index.html.erb",
        '<%= render partial: "user", collection: @users %>',
        "user"
      )

      assert.are.same(file_target({ "app/views/users/_user.html.erb" }), target)
    end)

    it("resolves a partial name from a namespaced controller", function()
      create_file("app/views/admin/users/_form.html.erb")

      local target = resolve("app/controllers/admin/users_controller.rb", '    render("form")', "form")

      assert.are.same(file_target({ "app/views/admin/users/_form.html.erb" }), target)
    end)

    it("accepts the :partial => syntax and single quotes", function()
      create_file("app/views/users/_row.html.erb")

      local target = resolve("app/views/users/index.html.erb", "<%= render :partial => 'row' %>", "row")

      assert.are.same(file_target({ "app/views/users/_row.html.erb" }), target)
    end)

    it("prefers the current file's format", function()
      create_file("app/views/users/_user.html.erb")
      create_file("app/views/users/_user.json.jbuilder")

      local target = resolve("app/views/users/index.json.jbuilder", 'json.partial! render "user"', "user")

      assert.are.same(file_target({ "app/views/users/_user.json.jbuilder" }), target)
    end)

    it("falls back to html and format-less partials when the format has none", function()
      create_file("app/views/users/_user.html.erb")
      create_file("app/views/users/_card.erb")

      assert.are.same(
        file_target({ "app/views/users/_user.html.erb" }),
        resolve("app/views/users/index.xml.builder", 'render "user"', "user")
      )
      assert.are.same(
        file_target({ "app/views/users/_card.erb" }),
        resolve("app/views/users/index.html.erb", 'render "card"', "card")
      )
    end)

    it("orders several engines by view.priority", function()
      create_file("app/views/users/_user.html.slim")
      create_file("app/views/users/_user.html.erb")
      create_file("app/views/users/_user.html.haml")

      local target = resolve("app/views/users/index.html.erb", 'render "user"', "user")

      assert.are.same(file_target({
        "app/views/users/_user.html.erb",
        "app/views/users/_user.html.haml",
        "app/views/users/_user.html.slim",
      }), target)
    end)

    it("keeps only the configured engine when view.engine is set", function()
      config.setup({ modules = { gf = true }, view = { engine = "haml" } })
      create_file("app/views/users/_user.html.erb")
      create_file("app/views/users/_user.html.haml")

      local target = resolve("app/views/users/index.html.haml", '= render "user"', "user")

      assert.are.same(file_target({ "app/views/users/_user.html.haml" }), target)
    end)

    it("reports a missing partial with the first path tried", function()
      local target = resolve("app/views/users/index.html.erb", '<%= render "shared/footer" %>', "footer")

      assert.are.same(
        { kind = "missing", message = "Rails: partial not found: app/views/shared/_footer.html.erb" },
        target
      )
    end)

    it("does not recognize a string that is not a render argument", function()
      create_file("app/views/users/_user.html.erb")

      assert.is_nil(resolve("app/views/users/index.html.erb", '<%= t("user") %>', "user"))
    end)

    it("does not recognize a partial name without a folder outside views and controllers", function()
      assert.is_nil(resolve("app/models/user.rb", '  render "user"', "user"))
    end)
  end)

  describe("resolve() fixtures", function()
    before_each(function()
      create_file("test/fixtures/users.yml", { "alice:", "  name: Alice", "", "bob:", "  name: Bob" })
    end)

    it("resolves a symbol in a fixtures declaration", function()
      local target = resolve("test/models/user_test.rb", "  fixtures :posts, :users", "users")

      assert.are.same(file_target({ "test/fixtures/users.yml" }), target)
    end)

    it("reports a declared fixture with no file", function()
      local target = resolve("test/models/user_test.rb", "  fixtures :users, :posts", "posts")

      assert.are.same({ kind = "missing", message = "Rails: fixture not found: test/fixtures/posts.yml" }, target)
    end)

    it("does not recognize fixtures :all", function()
      assert.is_nil(resolve("test/models/user_test.rb", "  fixtures :all", "all"))
    end)

    it("resolves a fixture accessor to the key line", function()
      local line = "    assert users(:bob).valid?"

      assert.are.same(
        file_target({ "test/fixtures/users.yml" }, { lnum = 4 }),
        resolve("test/models/user_test.rb", line, "users")
      )
      assert.are.same(
        file_target({ "test/fixtures/users.yml" }, { lnum = 4 }),
        resolve("test/models/user_test.rb", line, ":bob")
      )
    end)

    it("opens the fixture file at line 1 with a notice when the key is missing", function()
      local target = resolve("test/models/user_test.rb", "    users(:carol)", "users")

      assert.are.same(
        file_target(
          { "test/fixtures/users.yml" },
          { lnum = 1, notice = "Rails: fixture carol not found in test/fixtures/users.yml" }
        ),
        target
      )
    end)

    it("uses spec/fixtures when test/fixtures has no file", function()
      create_file("spec/fixtures/posts.yml", { "first:" })

      local target = resolve("spec/models/post_spec.rb", "    posts(:first)", "posts")

      assert.are.same(file_target({ "spec/fixtures/posts.yml" }, { lnum = 1 }), target)
    end)

    it("does not recognize a call without a fixture file", function()
      assert.is_nil(resolve("spec/models/user_spec.rb", "    build(:user)", "build"))
    end)

    it("does not recognize fixtures outside test and spec files", function()
      assert.is_nil(resolve("app/models/user.rb", "    users(:bob)", "users"))
    end)
  end)

  describe("resolve() migrations", function()
    local migration = "db/migrate/20240101000000_create_course_progresses.rb"

    before_each(function()
      create_file("app/models/course_progress.rb")
      create_file("app/models/user.rb")
      create_file("app/models/enrollment.rb")
    end)

    it("resolves the table of create_table, change_table and drop_table", function()
      assert.are.same(
        file_target({ "app/models/course_progress.rb" }),
        resolve(migration, "    create_table :course_progresses do |t|", "course")
      )
      assert.are.same(
        file_target({ "app/models/user.rb" }),
        resolve(migration, '    change_table "users" do |t|', "users")
      )
      assert.are.same(file_target({ "app/models/user.rb" }), resolve(migration, "    drop_table(:users)", "users"))
    end)

    it("resolves the table argument but not the column of add_column", function()
      local line = "    add_column :users, :email, :string, null: false"

      assert.are.same(file_target({ "app/models/user.rb" }), resolve(migration, line, ":users"))
      assert.is_nil(resolve(migration, line, "email"))
    end)

    it("resolves both tables of add_foreign_key", function()
      local line = "    add_foreign_key :enrollments, :users"

      assert.are.same(file_target({ "app/models/enrollment.rb" }), resolve(migration, line, "enrollments"))
      assert.are.same(file_target({ "app/models/user.rb" }), resolve(migration, line, ":users"))
    end)

    it("resolves references by their singular name", function()
      assert.are.same(
        file_target({ "app/models/enrollment.rb" }),
        resolve(migration, "      t.references :enrollment, null: false", "enrollment")
      )
      assert.are.same(file_target({ "app/models/user.rb" }), resolve(migration, "      t.belongs_to :user", "user"))
      assert.are.same(
        file_target({ "app/models/user.rb" }),
        resolve(migration, "    add_reference :enrollments, :user", ":user")
      )
    end)

    it("does not recognize other block columns", function()
      assert.is_nil(resolve(migration, "      t.string :user", "user"))
    end)

    it("prefers the annotate table name", function()
      create_file(
        "app/models/admin/user.rb",
        { "# == Schema Information", "#", "# Table name: admin_accounts", "#", "class Admin::User; end" }
      )

      local target = resolve(migration, "    create_table :admin_accounts do |t|", "admin_accounts")

      assert.are.same(file_target({ "app/models/admin/user.rb" }), target)
    end)

    it("reports a missing model", function()
      local target = resolve(migration, "    create_table :invoices do |t|", "invoices")

      assert.are.same({ kind = "missing", message = "Rails: model not found: app/models/invoice.rb" }, target)
    end)

    it("does not recognize tables outside migrations", function()
      assert.is_nil(resolve("app/models/user.rb", "    create_table :users", "users"))
    end)
  end)

  describe("resolve() route helpers", function()
    it("resolves _path and _url helpers to a route name", function()
      assert.are.same(
        { kind = "route", name = "edit_user" },
        resolve("app/views/users/index.html.erb", "<%= link_to 'Edit', edit_user_path(user) %>", "edit_user")
      )
      assert.are.same(
        { kind = "route", name = "users" },
        resolve("app/controllers/users_controller.rb", "    redirect_to main_app.users_url", "users_url")
      )
    end)

    it("does not recognize other words", function()
      assert.is_nil(resolve("app/models/user.rb", "  def full_name", "full_name"))
      assert.is_nil(resolve("app/models/user.rb", "  _path = 1", "_path"))
    end)
  end)

  describe("resolve_text()", function()
    it("resolves a selected partial path", function()
      create_file("app/views/shared/_header.html.erb")

      assert.are.same(
        file_target({ "app/views/shared/_header.html.erb" }),
        resolve_text("app/views/users/index.html.erb", '"shared/header"')
      )
    end)

    it("resolves a selected fixture, table and route helper", function()
      create_file("test/fixtures/users.yml")
      create_file("app/models/course_progress.rb")

      assert.are.same(file_target({ "test/fixtures/users.yml" }), resolve_text("app/models/user.rb", ":users"))
      assert.are.same(
        file_target({ "app/models/course_progress.rb" }),
        resolve_text("app/models/user.rb", "course_progresses")
      )
      assert.are.same({ kind = "route", name = "edit_user" }, resolve_text("app/models/user.rb", " edit_user_path "))
    end)

    it("returns nil when nothing matches", function()
      assert.is_nil(resolve_text("app/models/user.rb", "nothing_here"))
      assert.is_nil(resolve_text("app/models/user.rb", "  "))
    end)
  end)

  describe("setup()", function()
    local function gf_mapping(mode)
      return vim.fn.maparg("gf", mode, false, true)
    end

    it("maps gf in ruby buffers when modules.gf is true", function()
      gf.setup()
      open_in_buffer("app/models/user.rb", { "class User; end" }, { 1, 0 })

      assert.are.equal("Go to file (Rails-aware)", gf_mapping("n").desc)
      assert.are.equal("Go to file (Rails-aware)", gf_mapping("x").desc)
    end)

    it("maps gf in buffers already open at setup", function()
      open_in_buffer("app/models/user.rb", { "class User; end" }, { 1, 0 })

      gf.setup()

      assert.are.equal(1, gf_mapping("n").buffer)
    end)

    it("does nothing when modules.gf is false", function()
      config.setup({ modules = { gf = false } })

      gf.setup()
      open_in_buffer("app/models/user.rb", { "class User; end" }, { 1, 0 })

      assert.are_not.equal("Go to file (Rails-aware)", gf_mapping("n").desc)
    end)
  end)

  describe("gf mapping", function()
    before_each(function()
      gf.setup()
    end)

    local function press_gf()
      vim.fn.maparg("gf", "n", false, true).callback()
    end

    it("opens the resolved partial", function()
      create_file("app/views/shared/_header.html.erb")
      open_in_buffer("app/views/users/index.html.erb", { '<%= render "shared/header" %>' }, { 1, 15 })

      press_gf()

      assert.are.equal(tmp_dir .. "/app/views/shared/_header.html.erb", current_file())
    end)

    it("asks which partial to open when several match", function()
      create_file("app/views/users/_user.html.erb")
      create_file("app/views/users/_user.html.haml")
      select_choice = function(items)
        return items[2]
      end
      open_in_buffer("app/views/users/index.html.erb", { '<%= render "user" %>' }, { 1, 13 })

      press_gf()

      assert.are.equal("Rails partial", select_calls[1].opts.prompt)
      assert.are.equal(tmp_dir .. "/app/views/users/_user.html.haml", current_file())
    end)

    it("jumps to the fixture key line", function()
      create_file("test/fixtures/users.yml", { "alice:", "  name: Alice", "bob:" })
      open_in_buffer("test/models/user_test.rb", { "    users(:bob)" }, { 1, 5 })

      press_gf()

      assert.are.equal(tmp_dir .. "/test/fixtures/users.yml", current_file())
      assert.are.equal(3, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("notifies and stays when the target is missing", function()
      open_in_buffer("app/views/users/index.html.erb", { '<%= render "shared/footer" %>' }, { 1, 15 })

      press_gf()

      assert.are.same({ "Rails: partial not found: app/views/shared/_footer.html.erb" }, messages())
      assert.are.equal(tmp_dir .. "/app/views/users/index.html.erb", current_file())
    end)

    it("loads the routes and jumps to the action of a route helper", function()
      create_file("app/controllers/users_controller.rb", { "class UsersController", "  def edit", "  end", "end" })
      open_in_buffer("app/views/users/index.html.erb", { "<%= edit_user_path(user) %>" }, { 1, 6 })

      press_gf()
      vim.wait(JOB_WAIT_MS, function()
        return current_file() == tmp_dir .. "/app/controllers/users_controller.rb"
      end)

      assert.are.equal(tmp_dir .. "/app/controllers/users_controller.rb", current_file())
      assert.are.equal(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("notifies when no route has the helper's name", function()
      open_in_buffer("app/views/users/index.html.erb", { "<%= nowhere_path %>" }, { 1, 6 })

      press_gf()
      vim.wait(JOB_WAIT_MS, function()
        return vim.tbl_contains(messages(), "Rails: route not found: nowhere")
      end)

      assert.is_true(vim.tbl_contains(messages(), "Rails: route not found: nowhere"))
    end)

    it("falls back to the default gf outside a Rails context", function()
      create_file("lib/plain.rb", { "plain" })
      open_in_buffer("app/models/user.rb", { "lib/plain.rb" }, { 1, 2 })

      press_gf()

      assert.are.equal(tmp_dir .. "/lib/plain.rb", current_file())
    end)

    it("shows the default gf error without a stack trace", function()
      local echoed
      local orig_echo = vim.api.nvim_echo
      vim.api.nvim_echo = function(chunks)
        echoed = chunks
      end
      open_in_buffer("app/models/user.rb", { "no_such_file_here" }, { 1, 2 })

      press_gf()
      vim.api.nvim_echo = orig_echo

      assert.are.equal("ErrorMsg", echoed[1][2])
      assert.is_truthy(echoed[1][1]:match("^E447"))
    end)
  end)
end)
