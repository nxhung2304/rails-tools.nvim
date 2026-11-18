local MODULES_TO_RELOAD = {
  "rails-tools.core.rails_paths",
  "rails-tools.config",
}

describe("rails-tools.core.rails_paths", function()
  local rails_paths
  local config
  local tmp_dir

  local function create_file(relative_path)
    local path = tmp_dir .. "/" .. relative_path
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({}, path)
  end

  local function argument_kinds(line)
    return vim.tbl_map(function(argument)
      return { argument.name, argument.kind or "none" }
    end, rails_paths.migration_arguments(line))
  end

  before_each(function()
    for _, name in ipairs(MODULES_TO_RELOAD) do
      package.loaded[name] = nil
    end
    tmp_dir = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(tmp_dir, "p")
    config = require("rails-tools.config")
    config.setup({})
    rails_paths = require("rails-tools.core.rails_paths")
  end)

  after_each(function()
    vim.fn.delete(tmp_dir, "rf")
  end)

  it("relative_path() strips the root only when the file is under it", function()
    assert.are.equal("app/models/user.rb", rails_paths.relative_path("/app", "/app/app/models/user.rb"))
    assert.are.equal("/other/user.rb", rails_paths.relative_path("/app", "/other/user.rb"))
  end)

  it("format_of() reads the format part of a view name", function()
    assert.are.equal("json", rails_paths.format_of("app/views/users/index.json.jbuilder"))
    assert.are.equal("html", rails_paths.format_of("app/controllers/users_controller.rb"))
  end)

  it("default_engine() follows view.engine, else view.priority", function()
    assert.are.equal("erb", rails_paths.default_engine())

    config.setup({ view = { priority = { "slim", "erb" } } })
    assert.are.equal("slim", rails_paths.default_engine())

    config.setup({ view = { engine = "haml" } })
    assert.are.equal("haml", rails_paths.default_engine())
  end)

  it("view_candidates() keeps the format, then falls back to html and format-less views", function()
    create_file("app/views/users/show.json.jbuilder")
    create_file("app/views/users/show.html.erb")
    create_file("app/views/users/show.erb")

    assert.are.same(
      { "app/views/users/show.json.jbuilder" },
      rails_paths.view_candidates(tmp_dir, "users", "show", "json")
    )
    assert.are.same(
      { "app/views/users/show.erb", "app/views/users/show.html.erb" },
      rails_paths.view_candidates(tmp_dir, "users", "show", "xml")
    )
  end)

  it("migration_arguments() tells table, reference and other arguments apart", function()
    assert.are.same(
      { { "users", "table" }, { "email", "none" }, { "string", "none" } },
      argument_kinds("    add_column :users, :email, :string")
    )
    assert.are.same(
      { { "posts", "table" }, { "user", "reference" } },
      argument_kinds("    add_reference :posts, :user")
    )
    assert.are.same({ { "enrollment", "reference" } }, argument_kinds("      t.references :enrollment"))
    assert.are.same({ { "hello", "none" } }, argument_kinds("    puts 'hello'"))
  end)
end)
