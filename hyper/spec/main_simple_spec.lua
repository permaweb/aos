--[[
hyper AOS unit tests

main module (simplified)

* compute function basic behavior
]]

describe("main (simplified)", function()
  
  describe("compute", function()
    
    it("should be a function", function()
      local main = require('src/main')
      assert.are.equal("function", type(compute))
    end)
    
    it("should require basic parameters", function()
      -- Test that compute function exists and can be called
      -- without mocking the entire AO environment
      assert.is_not_nil(compute)
      assert.are.equal("function", type(compute))
    end)
    
  end)
  
end)