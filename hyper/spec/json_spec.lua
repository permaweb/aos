--[[
hyper AOS unit tests

json module

* encode function
* decode function
* error handling
* edge cases
]]

describe("json", function()
  
  local json
  
  before_each(function()
    json = require('src/json')
  end)
  
  after_each(function()
    package.loaded['src/json'] = nil
  end)
  
  describe("initialization", function()
    
    it("should have version 0.2.0", function()
      assert.are.equal("0.2.0", json._version)
    end)
    
    it("should have encode function", function()
      assert.are.equal("function", type(json.encode))
    end)
    
    it("should have decode function", function()
      assert.are.equal("function", type(json.decode))
    end)
    
  end)
  
  describe("encode", function()
    
    describe("basic types", function()
      
      it("should encode nil to null", function()
        assert.are.equal("null", json.encode(nil))
      end)
      
      it("should encode boolean true", function()
        assert.are.equal("true", json.encode(true))
      end)
      
      it("should encode boolean false", function()
        assert.are.equal("false", json.encode(false))
      end)
      
      it("should encode numbers", function()
        assert.are.equal("42", json.encode(42))
        assert.are.equal("3.14", json.encode(3.14))
        assert.are.equal("0", json.encode(0))
        assert.are.equal("-123", json.encode(-123))
      end)
      
      it("should encode strings", function()
        assert.are.equal('"hello"', json.encode("hello"))
        assert.are.equal('""', json.encode(""))
      end)
      
    end)
    
    describe("string escaping", function()
      
      it("should escape special characters", function()
        assert.are.equal('"hello\\nworld"', json.encode("hello\nworld"))
        assert.are.equal('"tab\\there"', json.encode("tab\there"))
        assert.are.equal('"quote\\""', json.encode('quote"'))
        assert.are.equal('"backslash\\\\"', json.encode("backslash\\"))
      end)
      
      it("should escape control characters", function()
        assert.are.equal('"\\b"', json.encode("\b"))
        assert.are.equal('"\\f"', json.encode("\f"))
        assert.are.equal('"\\r"', json.encode("\r"))
      end)
      
    end)
    
    describe("arrays", function()
      
      it("should encode empty array", function()
        assert.are.equal("[]", json.encode({}))
      end)
      
      it("should encode simple array", function()
        assert.are.equal("[1,2,3]", json.encode({1, 2, 3}))
      end)
      
      it("should encode mixed type array", function()
        local result = json.encode({1, "hello", true})
        assert.are.equal('[1,"hello",true]', result)
      end)
      
      it("should encode nested arrays", function()
        assert.are.equal("[[1,2],[3,4]]", json.encode({{1, 2}, {3, 4}}))
      end)
      
    end)
    
    describe("objects", function()
      
      it("should encode simple object", function()
        local result = json.encode({name = "John", age = 30})
        -- Since order is not guaranteed, check both possibilities
        local expected1 = '{"name":"John","age":30}'
        local expected2 = '{"age":30,"name":"John"}'
        assert.is_true(result == expected1 or result == expected2)
      end)
      
      it("should encode nested objects", function()
        local obj = {
          person = {
            name = "John",
            details = {age = 30}
          }
        }
        local result = json.encode(obj)
        assert.is_true(string.find(result, '"person"') ~= nil)
        assert.is_true(string.find(result, '"name":"John"') ~= nil)
        assert.is_true(string.find(result, '"age":30') ~= nil)
      end)
      
      it("should skip function values", function()
        local obj = {
          name = "John",
          func = function() end,
          age = 30
        }
        local result = json.encode(obj)
        assert.is_false(string.find(result, "func") ~= nil)
        assert.is_true(string.find(result, "name") ~= nil)
        assert.is_true(string.find(result, "age") ~= nil)
      end)
      
    end)
    
    describe("error cases", function()
      
      it("should error on invalid number values", function()
        assert.has_error(function()
          json.encode(math.huge)
        end)
        
        assert.has_error(function()
          json.encode(-math.huge)
        end)
        
        assert.has_error(function()
          json.encode(0/0) -- NaN
        end)
      end)
      
      it("should error on circular references", function()
        local obj = {}
        obj.self = obj
        
        assert.has_error(function()
          json.encode(obj)
        end)
      end)
      
      it("should error on mixed key types in tables", function()
        local mixed = {1, 2, name = "John"}
        
        assert.has_error(function()
          json.encode(mixed)
        end)
      end)
      
      it("should error on sparse arrays", function()
        local sparse = {1, nil, 3}
        sparse[5] = 5
        
        assert.has_error(function()
          json.encode(sparse)
        end)
      end)
      
      it("should error on non-string object keys", function()
        local obj = {}
        obj[42] = "number key"
        
        assert.has_error(function()
          json.encode(obj)
        end)
      end)
      
      it("should error on unsupported types", function()
        assert.has_error(function()
          json.encode(function() end)
        end)
        
        assert.has_error(function()
          json.encode(coroutine.create(function() end))
        end)
      end)
      
    end)
    
  end)
  
  describe("decode", function()
    
    describe("basic types", function()
      
      it("should decode null to nil", function()
        assert.is_nil(json.decode("null"))
      end)
      
      it("should decode booleans", function()
        assert.is_true(json.decode("true"))
        assert.is_false(json.decode("false"))
      end)
      
      it("should decode numbers", function()
        assert.are.equal(42, json.decode("42"))
        assert.are.equal(3.14, json.decode("3.14"))
        assert.are.equal(0, json.decode("0"))
        assert.are.equal(-123, json.decode("-123"))
      end)
      
      it("should decode strings", function()
        assert.are.equal("hello", json.decode('"hello"'))
        assert.are.equal("", json.decode('""'))
      end)
      
    end)
    
    describe("string unescaping", function()
      
      it("should unescape special characters", function()
        assert.are.equal("hello\nworld", json.decode('"hello\\nworld"'))
        assert.are.equal("tab\there", json.decode('"tab\\there"'))
        assert.are.equal('quote"', json.decode('"quote\\""'))
        assert.are.equal("backslash\\", json.decode('"backslash\\\\"'))
      end)
      
      it("should unescape control characters", function()
        assert.are.equal("\b", json.decode('"\\b"'))
        assert.are.equal("\f", json.decode('"\\f"'))
        assert.are.equal("\r", json.decode('"\\r"'))
      end)
      
    end)
    
    describe("arrays", function()
      
      it("should decode empty array", function()
        local result = json.decode("[]")
        assert.are.equal("table", type(result))
        assert.are.equal(0, #result)
      end)
      
      it("should decode simple array", function()
        local result = json.decode("[1,2,3]")
        assert.are.equal(3, #result)
        assert.are.equal(1, result[1])
        assert.are.equal(2, result[2])
        assert.are.equal(3, result[3])
      end)
      
      it("should decode mixed type array", function()
        local result = json.decode('[1,"hello",true,null]')
        -- Note: null becomes nil, which doesn't count in Lua array length
        assert.are.equal(3, #result)
        assert.are.equal(1, result[1])
        assert.are.equal("hello", result[2])
        assert.is_true(result[3])
        assert.is_nil(result[4]) -- This is still accessible but doesn't affect length
      end)
      
      it("should encode array with explicit nil", function()
        -- Note: Lua arrays with nil values are tricky
        local arr = {1, "hello", true}
        arr[4] = nil -- This won't actually set anything
        local result = json.encode(arr)
        assert.are.equal('[1,"hello",true]', result)
      end)
      
      it("should decode nested arrays", function()
        local result = json.decode("[[1,2],[3,4]]")
        assert.are.equal(2, #result)
        assert.are.equal(2, #result[1])
        assert.are.equal(1, result[1][1])
        assert.are.equal(4, result[2][2])
      end)
      
      it("should handle whitespace in arrays", function()
        local result = json.decode("[ 1 , 2 , 3 ]")
        assert.are.equal(3, #result)
        assert.are.equal(1, result[1])
      end)
      
    end)
    
    describe("objects", function()
      
      it("should decode empty object", function()
        local result = json.decode("{}")
        assert.are.equal("table", type(result))
        assert.is_nil(next(result)) -- empty table
      end)
      
      it("should decode simple object", function()
        local result = json.decode('{"name":"John","age":30}')
        assert.are.equal("John", result.name)
        assert.are.equal(30, result.age)
      end)
      
      it("should decode nested objects", function()
        local result = json.decode('{"person":{"name":"John","age":30}}')
        assert.are.equal("John", result.person.name)
        assert.are.equal(30, result.person.age)
      end)
      
      it("should handle whitespace in objects", function()
        local result = json.decode('{ "name" : "John" , "age" : 30 }')
        assert.are.equal("John", result.name)
        assert.are.equal(30, result.age)
      end)
      
    end)
    
    describe("error cases", function()
      
      it("should error on non-string input", function()
        assert.has_error(function()
          json.decode(42)
        end)
        
        assert.has_error(function()
          json.decode(nil)
        end)
      end)
      
      it("should error on invalid JSON", function()
        assert.has_error(function()
          json.decode("invalid")
        end)
        
        assert.has_error(function()
          json.decode("{invalid}")
        end)
        
        assert.has_error(function()
          json.decode("[1,2,")
        end)
      end)
      
      it("should error on trailing garbage", function()
        assert.has_error(function()
          json.decode('{"name":"John"} extra')
        end)
      end)
      
      it("should error on invalid escape sequences", function()
        assert.has_error(function()
          json.decode('"invalid\\x escape"')
        end)
      end)
      
      it("should error on control characters in strings", function()
        assert.has_error(function()
          json.decode('"\x01"') -- control character
        end)
      end)
      
      it("should error on unclosed strings", function()
        assert.has_error(function()
          json.decode('"unclosed string')
        end)
      end)
      
      it("should error on invalid numbers", function()
        assert.has_error(function()
          json.decode("123abc")
        end)
      end)
      
      it("should error on missing colons in objects", function()
        assert.has_error(function()
          json.decode('{"name" "John"}')
        end)
      end)
      
      it("should error on missing commas", function()
        assert.has_error(function()
          json.decode('[1 2 3]')
        end)
        
        assert.has_error(function()
          json.decode('{"a":1 "b":2}')
        end)
      end)
      
    end)
    
  end)
  
  describe("roundtrip", function()
    
    it("should encode and decode back to original", function()
      local original = {
        name = "John",
        age = 30,
        active = true,
        scores = {85, 92, 78},
        address = {
          street = "123 Main St",
          city = "Anytown"
        }
      }
      
      local encoded = json.encode(original)
      local decoded = json.decode(encoded)
      
      assert.are.equal(original.name, decoded.name)
      assert.are.equal(original.age, decoded.age)
      assert.are.equal(original.active, decoded.active)
      assert.are.equal(#original.scores, #decoded.scores)
      assert.are.equal(original.scores[1], decoded.scores[1])
      assert.are.equal(original.address.street, decoded.address.street)
    end)
    
    it("should handle arrays correctly", function()
      local original = {1, "hello", true, {nested = "value"}}
      local encoded = json.encode(original)
      local decoded = json.decode(encoded)
      
      assert.are.equal(#original, #decoded)
      assert.are.equal(original[1], decoded[1])
      assert.are.equal(original[2], decoded[2])
      assert.are.equal(original[3], decoded[3])
      assert.are.equal(original[4].nested, decoded[4].nested)
    end)
    
  end)
  
end)