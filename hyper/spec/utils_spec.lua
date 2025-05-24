--[[
hyper AOS unit tests

utils module

* matchesPattern
]]
local utils = require('src/utils')

describe("utils", function() 
  describe("matchesSpec", function() 
    it("should match action", function()
      assert.is_true(utils.matchesSpec({ action = "Balance"}, "Balance"))
    end)
    it("should match body.action", function() 
      assert.is_true(utils.matchesSpec({ body = { action = "Balance"}}, "Balance"))
    end)
    it("should match body.method", function()
      assert.is_true(utils.matchesSpec({ body = { method = "beep"}}, { method = "beep"}))
    end)
  end)
end)
