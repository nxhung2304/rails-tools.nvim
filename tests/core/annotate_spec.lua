local annotate = require("rails-tools.core.annotate")

describe("annotate.parse", function()
  it("returns no table_name and no columns when there is no annotate block", function()
    local lines = {
      "class User < ApplicationRecord",
      "  validates :email, presence: true",
      "end",
    }
    local block = annotate.parse(lines)
    assert.is_nil(block.table_name)
    assert.are.same({}, block.columns)
  end)

  it("parses the table name", function()
    local lines = {
      "# == Schema Information",
      "#",
      "# Table name: users",
      "#",
      "class User < ApplicationRecord",
      "end",
    }
    local block = annotate.parse(lines)
    assert.are.equal("users", block.table_name)
  end)

  it("parses column signatures", function()
    local lines = {
      "# == Schema Information",
      "#",
      "# Table name: users",
      "#",
      "#  id         :bigint           not null, primary key",
      "#  email      :string           not null",
      "#  status     :integer          default(\"active\"), not null",
      "#",
      "class User < ApplicationRecord",
      "end",
    }
    local block = annotate.parse(lines)
    assert.are.equal(":bigint not null, primary key", block.columns.id.signature)
    assert.are.equal(":string not null", block.columns.email.signature)
    assert.are.equal([[:integer default("active"), not null]], block.columns.status.signature)
  end)

  it("records the 1-indexed line number and 0-indexed column of each column name", function()
    local lines = {
      "# == Schema Information",
      "#",
      "#  email      :string           not null",
      "#",
    }
    local block = annotate.parse(lines)
    assert.are.equal(3, block.columns.email.lnum)
    assert.are.equal(3, block.columns.email.col) -- "#  email" -> "e" is byte index 4 (1-indexed) -> col 3
  end)

  it("stops parsing at the first non-comment line after the block starts", function()
    local lines = {
      "# == Schema Information",
      "#",
      "#  id  :bigint",
      "class User < ApplicationRecord",
      "#  ignored  :string",
      "end",
    }
    local block = annotate.parse(lines)
    assert.is_not_nil(block.columns.id)
    assert.is_nil(block.columns.ignored)
  end)

  it("does not mistake the Table name line or index lines for columns", function()
    local lines = {
      "# == Schema Information",
      "#",
      "# Table name: users",
      "#",
      "#  id  :bigint",
      "#",
      "# Indexes",
      "#",
      "#  index_users_on_email  (email) UNIQUE",
      "#",
    }
    local block = annotate.parse(lines)
    assert.is_nil(block.columns["Table"])
    assert.is_nil(block.columns["index_users_on_email"])
  end)
end)

describe("annotate.declared_table_name", function()
  it("reads a double-quoted name", function()
    assert.are.equal("orders", annotate.declared_table_name({ "class A", '  self.table_name = "orders"', "end" }))
  end)

  it("reads a single-quoted name", function()
    assert.are.equal("orders", annotate.declared_table_name({ "class A", "  self.table_name = 'orders'", "end" }))
  end)

  it("returns nil when the line is absent", function()
    assert.is_nil(annotate.declared_table_name({ "class A", "end" }))
  end)

  it("returns nil for a symbol value", function()
    assert.is_nil(annotate.declared_table_name({ "class A", "  self.table_name = :orders", "end" }))
  end)
end)

describe("annotate.scan", function()
  local tmp_dir

  before_each(function()
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir .. "/app/models", "p")
  end)

  after_each(function()
    vim.fn.delete(tmp_dir, "rf")
  end)

  local function write_model(name, lines)
    vim.fn.writefile(lines, tmp_dir .. "/app/models/" .. name .. ".rb")
  end

  it("returns a camelized model name keyed table with the parsed block and file path", function()
    write_model("user", {
      "# == Schema Information",
      "#",
      "# Table name: users",
      "#",
      "#  email  :string",
      "#",
      "class User < ApplicationRecord",
      "end",
    })

    local by_model = annotate.scan(tmp_dir)
    assert.is_not_nil(by_model.User)
    assert.are.equal("users", by_model.User.table_name)
    assert.are.equal(":string", by_model.User.columns.email.signature)
    assert.are.equal(tmp_dir .. "/app/models/user.rb", by_model.User.file)
  end)

  it("camelizes multi-word model filenames", function()
    write_model("order_item", {
      "# == Schema Information",
      "#",
      "# Table name: order_items",
      "#",
      "class OrderItem < ApplicationRecord",
      "end",
    })

    local by_model = annotate.scan(tmp_dir)
    assert.is_not_nil(by_model.OrderItem)
  end)

  it("includes models without any annotate block, with empty columns", function()
    write_model("plain", {
      "class Plain < ApplicationRecord",
      "end",
    })

    local by_model = annotate.scan(tmp_dir)
    assert.is_not_nil(by_model.Plain)
    assert.is_nil(by_model.Plain.table_name)
    assert.are.same({}, by_model.Plain.columns)
  end)

  it("keys namespaced models by full name, so same basenames do not collide", function()
    vim.fn.mkdir(tmp_dir .. "/app/models/admin", "p")
    write_model("user", { "# == Schema Information", "#", "# Table name: users", "#", "class User < ApplicationRecord", "end" })
    write_model("admin/user", {
      "# == Schema Information",
      "#",
      "# Table name: admin_users",
      "#",
      "class Admin::User < ApplicationRecord",
      "end",
    })

    local by_model = annotate.scan(tmp_dir)

    assert.are.equal("users", by_model.User.table_name)
    assert.are.equal("admin_users", by_model["Admin::User"].table_name)
    assert.are.equal(tmp_dir .. "/app/models/user.rb", by_model.User.file)
    assert.are.equal(tmp_dir .. "/app/models/admin/user.rb", by_model["Admin::User"].file)
  end)

  it("skips app/models/concerns", function()
    vim.fn.mkdir(tmp_dir .. "/app/models/concerns", "p")
    write_model("concerns/searchable", { "module Searchable", "end" })

    local by_model = annotate.scan(tmp_dir)

    assert.is_nil(by_model.Searchable)
    assert.is_nil(by_model["Concerns::Searchable"])
  end)

  it("stores the table name declared with self.table_name", function()
    write_model("legacy", { "class Legacy < ApplicationRecord", '  self.table_name = "legacy_users"', "end" })

    local by_model = annotate.scan(tmp_dir)

    assert.are.equal("legacy_users", by_model.Legacy.declared_table_name)
  end)
end)
