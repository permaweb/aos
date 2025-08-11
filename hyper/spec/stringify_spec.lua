--[[
hyper AOS unit tests

stringify module

* matchesPattern
]]
local stringify = require('src/stringify')
local colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m"
}

describe("stringify", function() 
  describe("format", function() 
    it("should format table list of strings", function()
      assert.are.same(stringify.format({ "hello" }), '{ ' .. colors.green ..'"hello"' .. colors.reset .. ' }')
    end)
    it("should format nested table", function() 
      assert.are.same(stringify.format({ foo = { bar = "baz"}}), string.format([[{
   %sfoo%s = {
     %sbar%s = %s"baz"%s
  }
}]], colors.red, colors.reset, colors.red, colors.reset, colors.green, colors.reset )) 
    end)
  end)
end)
