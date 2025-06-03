-- run with: busted hyper/spec/assignment_spec.lua

local utils = require "hyper.src.utils"

describe("matchesSpec", function()

  it("matches id equality", function()
    local spec = { id = "abc123" }
    assert.is_true(utils.matchesSpec({ id = "abc123" }, spec))
    assert.is_false(utils.matchesSpec({ id = "zzz"    }, spec))
  end)

  it("matches wildcard", function()
    local spec = { id = "*" }
    assert.is_true(utils.matchesSpec({ id = "anything" }, spec))
  end)

  it("matches regex", function()
    local spec = { id = "^tx_%d+$" }
    assert.is_true(utils.matchesSpec({ id = "tx_42" }, spec))
    assert.is_false(utils.matchesSpec({ id = "blob" }, spec))
  end)

  it("matches tag equality combo", function()
    local spec = { tags = { Action = "Ping", Group = "A" } }
    local msg  = { tags = { Action = "Ping", Group = "A", Extra = 1 } }
    assert.is_true(utils.matchesSpec(msg, spec))
  end)

  it("fails when a tag is absent", function()
    local spec = { tags = { Needs = "X" } }
    assert.is_false(utils.matchesSpec({ tags = { } }, spec))
  end)

end)