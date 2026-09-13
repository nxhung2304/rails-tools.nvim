local context = require("rails-tools.integrations.context")

describe("context.word_and_receiver", function()
  it("returns receiver and word for `user.status`, cursor on status", function()
    local line = "user.status"
    local receiver, word = context.word_and_receiver(line, 5) -- 0-indexed: 5 == 's' of status
    assert.are.equal("user", receiver)
    assert.are.equal("status", word)
  end)

  it("works with the cursor in the middle of the word", function()
    local line = "user.status"
    local receiver, word = context.word_and_receiver(line, 8) -- on the 't' in "status"
    assert.are.equal("user", receiver)
    assert.are.equal("status", word)
  end)

  it("works with the cursor on the last character of the word", function()
    local line = "user.status"
    local receiver, word = context.word_and_receiver(line, 10) -- last 's'
    assert.are.equal("user", receiver)
    assert.are.equal("status", word)
  end)

  it("returns nil receiver for a bare identifier with no dot", function()
    local line = "  status"
    local receiver, word = context.word_and_receiver(line, 3)
    assert.is_nil(receiver)
    assert.are.equal("status", word)
  end)

  it("resolves self as the receiver", function()
    local line = "self.status"
    local receiver, word = context.word_and_receiver(line, 6)
    assert.are.equal("self", receiver)
    assert.are.equal("status", word)
  end)

  it("resolves an ivar receiver, stripping the @", function()
    local line = "@current_user.email"
    local receiver, word = context.word_and_receiver(line, 15)
    assert.are.equal("current_user", receiver)
    assert.are.equal("email", word)
  end)

  it("snaps to the preceding word when the cursor sits on the dot", function()
    local line = "user.status"
    local receiver, word = context.word_and_receiver(line, 4) -- the dot
    assert.is_nil(receiver)
    assert.are.equal("user", word)
  end)

  it("returns nil, nil when the cursor is on whitespace between two words", function()
    local line = "user . status"
    local receiver, word = context.word_and_receiver(line, 5) -- the space after the dot
    assert.is_nil(receiver)
    assert.is_nil(word)
  end)

  it("returns nil, nil for an empty line", function()
    local receiver, word = context.word_and_receiver("", 0)
    assert.is_nil(receiver)
    assert.is_nil(word)
  end)

  it("does not treat a method call chain as a receiver beyond the immediate identifier", function()
    local line = "users.first.status"
    local receiver, word = context.word_and_receiver(line, 13) -- 's' in status
    assert.are.equal("first", receiver)
    assert.are.equal("status", word)
  end)
end)
