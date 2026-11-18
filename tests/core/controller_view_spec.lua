local MODULES_TO_RELOAD = {
  "rails-tools.core.controller_view",
  "rails-tools.core.related_files",
  "rails-tools.core.rails_file_kind",
  "rails-tools.core.rails_paths",
  "rails-tools.config",
  "rails-tools.detectors.rails",
}

local USERS_CONTROLLER = {
  "class UsersController < ApplicationController",
  "  def index",
  "    @users = User.all",
  "  end",
  "",
  "  def show",
  "  end",
  "",
  "  def self.build",
  "  end",
  "",
  "  private",
  "",
  "  def set_user",
  "  end",
  "end",
}

describe("rails-tools.core.controller_view", function()
  local controller_view
  local config
  local tmp_dir
  local orig_cwd
  local orig_notify
  local orig_select
  local orig_input
  local notifications
  local select_calls
  local select_choice
  local input_answer
  local input_prompts

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

  local function context(relative_file, lines, cursor_lnum)
    return { root = tmp_dir, relative_file = relative_file, lines = lines or {}, cursor_lnum = cursor_lnum or 1 }
  end

  local function find_paths(relative_file, type, lines, cursor_lnum)
    local entries, missing = controller_view.find(context(relative_file, lines, cursor_lnum), type)
    local paths = vim.tbl_map(function(entry)
      return entry.path
    end, entries)
    return paths, missing
  end

  local function messages()
    return vim.tbl_map(function(notification)
      return notification.msg
    end, notifications)
  end

  local function open_in_buffer(relative_file, lines, cursor)
    create_file(relative_file, lines)
    vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/" .. relative_file))
    vim.api.nvim_win_set_cursor(0, cursor or { 1, 0 })
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

    input_answer = ""
    input_prompts = {}
    orig_input = vim.fn.input
    vim.fn.input = function(prompt)
      table.insert(input_prompts, prompt)
      return input_answer
    end

    config = require("rails-tools.config")
    config.setup({ modules = { controller_view = true } })
    controller_view = require("rails-tools.core.controller_view")

    create_file("Gemfile")
    create_file("bin/rails")
    vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.ui.select = orig_select
    vim.fn.input = orig_input
    vim.cmd("silent! %bwipeout!")
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_dir, "rf")
    reload_modules()
  end)

  describe("kind_of()", function()
    it("recognizes controllers, views, models, migrations and helpers", function()
      assert.are.same(
        { kind = "controller", path = "admin/users" },
        controller_view.kind_of("app/controllers/admin/users_controller.rb")
      )
      assert.are.same(
        { kind = "view", folder = "users", action = "show", is_partial = false, is_layout = false },
        controller_view.kind_of("app/views/users/show.html.erb")
      )
      assert.are.same({ kind = "model", path = "admin/user" }, controller_view.kind_of("app/models/admin/user.rb"))
      assert.are.same({ kind = "migration" }, controller_view.kind_of("db/migrate/20240101000000_create_users.rb"))
      assert.are.same({ kind = "helper", path = "users" }, controller_view.kind_of("app/helpers/users_helper.rb"))
    end)

    it("marks partials and layouts", function()
      assert.is_true(controller_view.kind_of("app/views/users/_form.html.erb").is_partial)
      assert.is_true(controller_view.kind_of("app/views/layouts/application.html.erb").is_layout)
      assert.is_true(controller_view.kind_of("app/views/layouts/admin/base.html.erb").is_layout)
    end)

    it("returns nil for concerns, dot files in views and other files", function()
      assert.is_nil(controller_view.kind_of("app/models/concerns/searchable.rb"))
      assert.is_nil(controller_view.kind_of("app/views/users/.keep"))
      assert.is_nil(controller_view.kind_of("lib/tasks/seed.rake"))
    end)
  end)

  describe("action_at()", function()
    it("returns the public action at or above the cursor", function()
      assert.are.equal("index", controller_view.action_at(USERS_CONTROLLER, 2))
      assert.are.equal("index", controller_view.action_at(USERS_CONTROLLER, 3))
      assert.are.equal("show", controller_view.action_at(USERS_CONTROLLER, 7))
    end)

    it("returns nil above the first def, on a class method and after private", function()
      assert.is_nil(controller_view.action_at(USERS_CONTROLLER, 1))
      assert.is_nil(controller_view.action_at(USERS_CONTROLLER, 9))
      assert.is_nil(controller_view.action_at(USERS_CONTROLLER, 14))
    end)

    it("returns nil for an inline private def", function()
      assert.is_nil(controller_view.action_at({ "class A", "  private def secret", "  end" }, 2))
    end)
  end)

  describe("find() view", function()
    local controller = "app/controllers/users_controller.rb"

    it("returns the action views, html first and engines in view.priority order", function()
      create_file("app/views/users/show.json.jbuilder")
      create_file("app/views/users/show.html.haml")
      create_file("app/views/users/show.html.erb")

      local paths = find_paths(controller, "view", USERS_CONTROLLER, 6)

      assert.are.same({ "app/views/users/show.html.erb", "app/views/users/show.html.haml" }, paths)
    end)

    it("lists every view of the controller outside an action", function()
      create_file("app/views/users/index.html.erb")
      create_file("app/views/users/_form.html.erb")

      local paths = find_paths(controller, "view", USERS_CONTROLLER, 1)

      assert.are.same({ "app/views/users/_form.html.erb", "app/views/users/index.html.erb" }, paths)
    end)

    it("handles namespaced controllers", function()
      create_file("app/views/admin/users/index.html.erb")

      local paths = find_paths("app/controllers/admin/users_controller.rb", "view", USERS_CONTROLLER, 2)

      assert.are.same({ "app/views/admin/users/index.html.erb" }, paths)
    end)

    it("offers to create a missing action view with the default engine", function()
      config.setup({ modules = { controller_view = true }, view = { engine = "slim" } })

      local paths, missing = find_paths(controller, "view", USERS_CONTROLLER, 6)

      assert.are.same({}, paths)
      assert.are.same({
        message = "Rails: view not found: app/views/users/show.html.slim",
        create_path = "app/views/users/show.html.slim",
      }, missing)
    end)
  end)

  describe("find() controller", function()
    it("opens the controller of a view at its action", function()
      create_file("app/controllers/users_controller.rb", USERS_CONTROLLER)

      local entries = controller_view.find(context("app/views/users/show.html.erb"), "controller")

      assert.are.same({ { type = "controller", path = "app/controllers/users_controller.rb", lnum = 6 } }, entries)
    end)

    it("opens the controller at line 1 for a partial", function()
      create_file("app/controllers/users_controller.rb", USERS_CONTROLLER)

      local entries = controller_view.find(context("app/views/users/_form.html.erb"), "controller")

      assert.are.equal(1, entries[1].lnum)
    end)

    it("falls back to the mailer of a mailer view", function()
      create_file("app/mailers/user_mailer.rb", { "class UserMailer", "  def welcome", "  end", "end" })

      local entries = controller_view.find(context("app/views/user_mailer/welcome.text.erb"), "controller")

      assert.are.same({ { type = "controller", path = "app/mailers/user_mailer.rb", lnum = 2 } }, entries)
    end)

    it("has no controller for a layout or a missing controller", function()
      local _, layout_missing = find_paths("app/views/layouts/application.html.erb", "controller")
      local _, controller_missing = find_paths("app/views/posts/index.html.erb", "controller")

      assert.are.equal("Rails: no controller for a layout view", layout_missing.message)
      assert.are.equal("Rails: controller not found: app/controllers/posts_controller.rb", controller_missing.message)
    end)

    it("finds the plural controller of a model and the controller of a helper", function()
      create_file("app/controllers/admin/users_controller.rb")
      create_file("app/controllers/users_controller.rb")

      assert.are.same(
        { "app/controllers/admin/users_controller.rb" },
        (find_paths("app/models/admin/user.rb", "controller"))
      )
      assert.are.same(
        { "app/controllers/users_controller.rb" },
        (find_paths("app/helpers/users_helper.rb", "controller"))
      )
    end)
  end)

  describe("find() helper, model and layout", function()
    it("finds the helper of a controller and a view", function()
      create_file("app/helpers/admin/users_helper.rb")

      assert.are.same(
        { "app/helpers/admin/users_helper.rb" },
        (find_paths("app/controllers/admin/users_controller.rb", "helper"))
      )
      assert.are.same(
        { "app/helpers/admin/users_helper.rb" },
        (find_paths("app/views/admin/users/index.html.erb", "helper"))
      )
    end)

    it("prefers the namespaced model, then the plain one", function()
      create_file("app/models/user.rb")

      assert.are.same({ "app/models/user.rb" }, (find_paths("app/controllers/admin/users_controller.rb", "model")))

      create_file("app/models/admin/user.rb")

      assert.are.same(
        { "app/models/admin/user.rb" },
        (find_paths("app/controllers/admin/users_controller.rb", "model"))
      )
    end)

    it("finds the model of the first table in a migration", function()
      create_file("app/models/course_progress.rb")
      local migration = {
        "class CreateCourseProgresses < ActiveRecord::Migration[7.1]",
        "  def change",
        "    create_table :course_progresses do |t|",
      }

      assert.are.same({ "app/models/course_progress.rb" }, (find_paths("db/migrate/1_create.rb", "model", migration)))
    end)

    it("uses the controller's layout, else the application layout", function()
      create_file("app/views/layouts/application.html.erb")

      assert.are.same(
        { "app/views/layouts/application.html.erb" },
        (find_paths("app/controllers/users_controller.rb", "layout"))
      )

      create_file("app/views/layouts/users.html.erb")

      assert.are.same(
        { "app/views/layouts/users.html.erb" },
        (find_paths("app/controllers/users_controller.rb", "layout"))
      )
    end)
  end)

  describe("find() schema, fixture and migration", function()
    before_each(function()
      create_file("app/models/user.rb", { "class User; end" })
    end)

    it("opens db/schema.rb at the model's table", function()
      create_file("db/schema.rb", {
        "ActiveRecord::Schema.define do",
        '  create_table "posts" do |t|',
        "  end",
        '  create_table "users" do |t|',
        "  end",
        "end",
      })

      local entries = controller_view.find(context("app/models/user.rb"), "schema")

      assert.are.same({ { type = "schema", path = "db/schema.rb", lnum = 4 } }, entries)
    end)

    it("reports a missing schema file or table", function()
      local _, no_file = find_paths("app/models/user.rb", "schema")
      create_file("db/schema.rb", { '  create_table "posts" do |t|' })
      local _, no_table = find_paths("app/models/user.rb", "schema")

      assert.are.equal("Rails: schema not found: db/schema.rb", no_file.message)
      assert.are.equal("Rails: table users not found in db/schema.rb", no_table.message)
    end)

    it("uses the annotate table name", function()
      create_file("app/models/admin/user.rb", { "# == Schema Information", "#", "# Table name: admin_accounts", "#" })
      create_file("test/fixtures/admin_accounts.yml")

      assert.are.same({ "test/fixtures/admin_accounts.yml" }, (find_paths("app/models/admin/user.rb", "fixture")))
    end)

    it("finds the fixture of the pluralized model name", function()
      create_file("spec/fixtures/users.yml")

      assert.are.same({ "spec/fixtures/users.yml" }, (find_paths("app/models/user.rb", "fixture")))
    end)

    it("lists every migration that touches the table, newest first", function()
      create_file("db/migrate/20240101000000_create_users.rb", { "    create_table :users do |t|" })
      create_file(
        "db/migrate/20240201000000_create_posts.rb",
        { "    create_table :posts do |t|", "      t.references :user" }
      )
      create_file("db/migrate/20240301000000_add_email_to_users.rb", { "    add_column :users, :email, :string" })

      local paths = find_paths("app/models/user.rb", "migration")

      assert.are.same({
        "db/migrate/20240301000000_add_email_to_users.rb",
        "db/migrate/20240101000000_create_users.rb",
      }, paths)
    end)
  end)

  describe("find() limits", function()
    it("refuses a type that does not apply to the file kind", function()
      local _, missing = find_paths("app/models/user.rb", "view")

      assert.are.equal("Rails: no view for this file", missing.message)
    end)
  end)

  describe("related()", function()
    it("lists only the related files that exist, in type order", function()
      create_file("app/controllers/users_controller.rb", USERS_CONTROLLER)
      create_file("app/helpers/users_helper.rb")
      create_file("app/models/user.rb")

      local entries = controller_view.related(context("app/views/users/show.html.erb"))

      assert.are.same({
        { type = "controller", path = "app/controllers/users_controller.rb", lnum = 6 },
        { type = "helper", path = "app/helpers/users_helper.rb" },
        { type = "model", path = "app/models/user.rb" },
      }, entries)
    end)
  end)

  describe("commands", function()
    it("toggle() goes from a controller action to its view and back", function()
      create_file("app/views/users/show.html.erb")
      open_in_buffer("app/controllers/users_controller.rb", USERS_CONTROLLER, { 6, 0 })

      controller_view.toggle()
      assert.are.equal(tmp_dir .. "/app/views/users/show.html.erb", current_file())

      controller_view.toggle()
      assert.are.equal(tmp_dir .. "/app/controllers/users_controller.rb", current_file())
      assert.are.equal(6, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("toggle() says so outside a controller or view", function()
      open_in_buffer("app/models/user.rb")

      controller_view.toggle()

      assert.are.same({ "Rails: not a controller or view" }, messages())
    end)

    it("to_view() asks before creating a missing view and creates it on y", function()
      open_in_buffer("app/controllers/users_controller.rb", USERS_CONTROLLER, { 6, 0 })
      input_answer = "y"

      controller_view.to_view()

      assert.are.same({ "Create app/views/users/show.html.erb ? (y/N): " }, input_prompts)
      assert.are.equal(tmp_dir .. "/app/views/users/show.html.erb", current_file())
      assert.are.equal(1, vim.fn.filereadable(tmp_dir .. "/app/views/users/show.html.erb"))
    end)

    it("to_view() creates nothing when the prompt is declined", function()
      open_in_buffer("app/controllers/users_controller.rb", USERS_CONTROLLER, { 6, 0 })
      input_answer = "n"

      controller_view.to_view()

      assert.are.equal(0, vim.fn.isdirectory(tmp_dir .. "/app/views/users"))
      assert.are.equal(tmp_dir .. "/app/controllers/users_controller.rb", current_file())
    end)

    it("to_view() picks between several views", function()
      create_file("app/views/users/show.html.erb")
      create_file("app/views/users/show.html.haml")
      select_choice = function(items)
        return items[2]
      end
      open_in_buffer("app/controllers/users_controller.rb", USERS_CONTROLLER, { 6, 0 })

      controller_view.to_view()

      assert.are.equal(tmp_dir .. "/app/views/users/show.html.haml", current_file())
    end)

    it("related_menu() labels entries with their type", function()
      create_file("app/helpers/users_helper.rb")
      create_file("app/models/user.rb")
      open_in_buffer("app/controllers/users_controller.rb", USERS_CONTROLLER, { 1, 0 })

      controller_view.related_menu()

      local labels = vim.tbl_map(select_calls[1].opts.format_item, select_calls[1].items)
      assert.are.same({ "helper: app/helpers/users_helper.rb", "model: app/models/user.rb" }, labels)
      assert.are.equal("Rails related", select_calls[1].opts.prompt)
    end)

    it("related_menu() says so when nothing is related", function()
      open_in_buffer("lib/tasks/seed.rake")

      controller_view.related_menu()

      assert.are.same({ "Rails: no related files for this file" }, messages())
    end)

    it("open_type() opens a single file at its line", function()
      create_file("db/schema.rb", { "ActiveRecord::Schema.define do", '  create_table "users" do |t|' })
      open_in_buffer("app/models/user.rb", { "class User; end" })

      controller_view.open_type("schema")

      assert.are.equal(tmp_dir .. "/db/schema.rb", current_file())
      assert.are.equal(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("open_type() shows the usage for an unknown type", function()
      open_in_buffer("app/models/user.rb")

      controller_view.open_type("spec")

      assert.are.same(
        { "Rails: usage: :Rails related [view|controller|helper|model|layout|schema|fixture|migration]" },
        messages()
      )
    end)

    it("warns outside a Rails project", function()
      vim.fn.delete(tmp_dir .. "/Gemfile")
      open_in_buffer("app/models/user.rb")

      controller_view.related_menu()

      assert.are.same({ "Rails: not a Rails project" }, messages())
    end)
  end)
end)
