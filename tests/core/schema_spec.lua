local schema = require("rails-tools.core.schema")

local SAMPLE_SCHEMA = {
  'ActiveRecord::Schema[7.1].define(version: 2024_01_01_000000) do',
  '  create_table "users", force: :cascade do |t|',
  '    t.string "email", null: false',
  '    t.string "name"',
  '    t.integer "status", default: 0, null: false',
  '    t.datetime "created_at", null: false',
  '    t.datetime "updated_at", null: false',
  '    t.index ["email"], name: "index_users_on_email", unique: true',
  '  end',
  '',
  '  create_table "orders", force: :cascade do |t|',
  '    t.bigint "user_id", null: false',
  '    t.string "status"',
  '    t.index ["user_id"], name: "index_orders_on_user_id"',
  '  end',
  'end',
}

describe("schema.parse", function()
  it("returns a table keyed by table name", function()
    local tables = schema.parse(SAMPLE_SCHEMA)
    assert.is_not_nil(tables.users)
    assert.is_not_nil(tables.orders)
  end)

  it("parses column type and signature", function()
    local tables = schema.parse(SAMPLE_SCHEMA)
    assert.are.equal("string", tables.users.columns.email.type)
    assert.are.equal("null: false", tables.users.columns.email.signature)
  end)

  it("parses a column with no extra signature", function()
    local tables = schema.parse(SAMPLE_SCHEMA)
    assert.are.equal("string", tables.users.columns.name.type)
    assert.are.equal("", tables.users.columns.name.signature)
  end)

  it("preserves default values in the signature", function()
    local tables = schema.parse(SAMPLE_SCHEMA)
    assert.are.equal("default: 0, null: false", tables.users.columns.status.signature)
  end)

  it("records the line number of each column", function()
    local tables = schema.parse(SAMPLE_SCHEMA)
    assert.are.equal(3, tables.users.columns.email.lnum)
  end)

  it("records the line number of the create_table call", function()
    local tables = schema.parse(SAMPLE_SCHEMA)
    assert.are.equal(2, tables.users.lnum)
    assert.are.equal(11, tables.orders.lnum)
  end)

  it("collects t.index lines as indexes", function()
    local tables = schema.parse(SAMPLE_SCHEMA)
    assert.are.equal(1, #tables.users.indexes)
    assert.matches("index_users_on_email", tables.users.indexes[1])
  end)

  it("does not leak columns across tables", function()
    local tables = schema.parse(SAMPLE_SCHEMA)
    assert.is_nil(tables.users.columns.user_id)
    assert.is_not_nil(tables.orders.columns.user_id)
  end)

  it("returns an empty table for schema with no create_table calls", function()
    local tables = schema.parse({ "ActiveRecord::Schema[7.1].define do", "end" })
    assert.are.same({}, tables)
  end)
end)

describe("schema.load", function()
  local tmp_dir

  before_each(function()
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir .. "/db", "p")
  end)

  after_each(function()
    vim.fn.delete(tmp_dir, "rf")
  end)

  it("loads and parses db/schema.rb under the given root", function()
    vim.fn.writefile(SAMPLE_SCHEMA, tmp_dir .. "/db/schema.rb")
    local tables = schema.load(tmp_dir)
    assert.is_not_nil(tables)
    assert.is_not_nil(tables.users)
  end)

  it("returns nil when db/schema.rb does not exist", function()
    assert.is_nil(schema.load(tmp_dir))
  end)
end)

describe("schema.resolve", function()
  local tmp_dir

  before_each(function()
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir .. "/db", "p")
    vim.fn.mkdir(tmp_dir .. "/app/models", "p")
    vim.fn.writefile({ "" }, tmp_dir .. "/Gemfile")
    vim.fn.mkdir(tmp_dir .. "/bin", "p")
    vim.fn.writefile({ "" }, tmp_dir .. "/bin/rails")
  end)

  after_each(function()
    schema.invalidate(tmp_dir)
    vim.fn.delete(tmp_dir, "rf")
  end)

  local function write(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(tmp_dir .. "/" .. path, ":h"), "p")
    vim.fn.writefile(lines, tmp_dir .. "/" .. path)
  end

  it("prefers the annotate signature and jumps to the annotate comment line", function()
    write("db/schema.rb", SAMPLE_SCHEMA)
    write("app/models/user.rb", {
      "# == Schema Information",
      "#",
      "# Table name: users",
      "#",
      "#  email  :string not null, unique",
      "#",
      "class User < ApplicationRecord",
      "end",
    })

    local resolved = schema.resolve(tmp_dir)
    local email = resolved.models.User.columns.email
    assert.are.equal(":string not null, unique", email.signature)
    assert.are.equal(tmp_dir .. "/app/models/user.rb", email.location.file)
  end)

  it("falls back to db/schema.rb for a column missing from the annotate block", function()
    write("db/schema.rb", SAMPLE_SCHEMA)
    write("app/models/user.rb", {
      "# == Schema Information",
      "#",
      "# Table name: users",
      "#",
      "#  email  :string",
      "#",
      "class User < ApplicationRecord",
      "end",
    })

    local resolved = schema.resolve(tmp_dir)
    local status = resolved.models.User.columns.status
    assert.are.equal(":integer default: 0, null: false", status.signature)
    assert.are.equal(tmp_dir .. "/db/schema.rb", status.location.file)
  end)

  it("falls back to the annotate comment location for implicit columns like id", function()
    write("db/schema.rb", SAMPLE_SCHEMA)
    write("app/models/user.rb", {
      "# == Schema Information",
      "#",
      "# Table name: users",
      "#",
      "#  id  :bigint not null, primary key",
      "#",
      "class User < ApplicationRecord",
      "end",
    })

    local resolved = schema.resolve(tmp_dir)
    local id = resolved.models.User.columns.id
    assert.are.equal(tmp_dir .. "/app/models/user.rb", id.location.file)
  end)

  it("includes every app/models file in known_models, annotated or not", function()
    write("app/models/user.rb", { "class User < ApplicationRecord", "end" })
    write("app/models/order.rb", {
      "# == Schema Information",
      "# Table name: orders",
      "class Order < ApplicationRecord",
      "end",
    })

    local resolved = schema.resolve(tmp_dir)
    assert.is_true(resolved.known_models.User)
    assert.is_true(resolved.known_models.Order)
  end)

  it("caches the result per root", function()
    write("app/models/user.rb", { "class User < ApplicationRecord", "end" })
    local first = schema.resolve(tmp_dir)
    write("app/models/order.rb", { "class Order < ApplicationRecord", "end" })
    local second = schema.resolve(tmp_dir)
    assert.are.equal(first, second)
    assert.is_nil(second.known_models.Order)
  end)

  it("reflects new files after invalidate()", function()
    write("app/models/user.rb", { "class User < ApplicationRecord", "end" })
    schema.resolve(tmp_dir)
    write("app/models/order.rb", { "class Order < ApplicationRecord", "end" })
    schema.invalidate(tmp_dir)
    local resolved = schema.resolve(tmp_dir)
    assert.is_true(resolved.known_models.Order)
  end)
end)

describe("schema.setup", function()
  local tmp_dir

  before_each(function()
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir .. "/app/models", "p")
    vim.fn.mkdir(tmp_dir .. "/db", "p")
    vim.fn.writefile({ "" }, tmp_dir .. "/Gemfile")
    vim.fn.mkdir(tmp_dir .. "/bin", "p")
    vim.fn.writefile({ "" }, tmp_dir .. "/bin/rails")
    schema.setup()
  end)

  after_each(function()
    vim.cmd("silent! bwipeout!")
    schema.invalidate(tmp_dir)
    vim.fn.delete(tmp_dir, "rf")
  end)

  it("invalidates the resolved cache when a saved model file drops its annotate block", function()
    local model_path = tmp_dir .. "/app/models/user.rb"
    vim.fn.writefile({
      "# == Schema Information",
      "#",
      "# Table name: users",
      "#",
      "#  email  :string not null",
      "#",
      "class User < ApplicationRecord",
      "end",
    }, model_path)

    local before = schema.resolve(tmp_dir)
    assert.is_not_nil(before.models.User.columns.email)

    vim.cmd("edit " .. model_path)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "class User < ApplicationRecord", "end" })
    vim.cmd("write")

    local after = schema.resolve(tmp_dir)
    assert.is_nil(after.models.User.columns.email)
  end)

  it("does not invalidate for a .rb file outside app/models or db/schema.rb", function()
    vim.fn.mkdir(tmp_dir .. "/app/services", "p")
    local other_path = tmp_dir .. "/app/services/user_service.rb"
    vim.fn.writefile({ "class UserService", "end" }, other_path)

    local before = schema.resolve(tmp_dir)

    vim.cmd("edit " .. other_path)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "class UserService", "def call; end", "end" })
    vim.cmd("write")

    local after = schema.resolve(tmp_dir)
    assert.are.equal(before, after)
  end)
end)
