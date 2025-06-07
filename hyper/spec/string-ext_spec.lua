--[[
hyper AOS unit tests

string-ext module

* string.gmatch implementation
]]
local string_ext = require('src/string-ext')

describe("string-ext", function()
  
  -- Store original function to restore later
  local original_gmatch = string.gmatch
  
  -- Install the extensions before running tests
  before_each(function()
    -- Force our implementation by clearing existing functions first
    -- busted breaks if we don't do this
    string.gmatch = nil
    string_ext.install()
  end)
  
  -- Restore original functions after tests
  after_each(function()
    string.gmatch = original_gmatch
  end)
  
  describe("string.gmatch", function()
    
    it("should exist after installation", function()
      assert.is_not_nil(string.gmatch)
      assert.are.equal("function", type(string.gmatch))
    end)
    
    it("should find simple patterns", function()
      local results = {}
      for word in string.gmatch("hello world test", "%w+") do
        table.insert(results, word)
      end
      assert.are.same({"hello", "world", "test"}, results)
    end)
    
    it("should find digit patterns", function()
      local results = {}
      for num in string.gmatch("abc123def456ghi", "%d+") do
        table.insert(results, num)
      end
      assert.are.same({"123", "456"}, results)
    end)
    
    it("should handle captures", function()
      local results = {}
      for name, value in string.gmatch("name=john age=25 city=nyc", "(%w+)=(%w+)") do
        table.insert(results, {name, value})
      end
      assert.are.same({{"name", "john"}, {"age", "25"}, {"city", "nyc"}}, results)
    end)
    
    it("should handle empty string", function()
      local count = 0
      for match in string.gmatch("", "%w+") do
        count = count + 1
      end
      assert.are.equal(0, count)
    end)
    
    it("should handle no matches", function()
      local count = 0
      for match in string.gmatch("abc", "%d+") do
        count = count + 1
      end
      assert.are.equal(0, count)
    end)
    
    it("should handle single character matches", function()
      local results = {}
      for char in string.gmatch("a1b2c3", "%a") do
        table.insert(results, char)
      end
      assert.are.same({"a", "b", "c"}, results)
    end)
    
    it("should handle line iteration like in process.lua", function()
      local input = "line1\nline2\nline3\n"
      local results = {}
      for line in string.gmatch(input, "([^\n]*)\n?") do
        if line ~= "" then  -- Skip empty matches
          table.insert(results, line)
        end
      end
      assert.are.same({"line1", "line2", "line3"}, results)
    end)
    
    it("should throw error for non-string input", function()
      assert.has_error(function()
        local iter = string.gmatch(123, "%w+")
        iter() -- Call the iterator to trigger the error
      end)
    end)
    
    it("should throw error for non-string pattern", function()
      assert.has_error(function()
        local iter = string.gmatch("hello", 123)
        iter() -- Call the iterator to trigger the error
      end)
    end)
    
    it("should throw error with correct message for non-string input", function()
      local success, err = pcall(function()
        string.gmatch(123, "%w+")
      end)
      assert.is_false(success)
      assert.matches("bad argument #1 to 'gmatch'", err)
      assert.matches("string expected, got number", err)
    end)
    
    it("should throw error with correct message for non-string pattern", function()
      local success, err = pcall(function()
        string.gmatch("hello", 123)
      end)
      assert.is_false(success)
      assert.matches("bad argument #2 to 'gmatch'", err)
      assert.matches("string expected, got number", err)
    end)
  end)
  
  describe("Zero-Width Matches and Boundary Conditions", function()
    
    it("should handle zero-width matches correctly", function()
      local results = {}
      local count = 0
      for match in string.gmatch("abc", "()") do -- Empty capture at position
        table.insert(results, match)
        count = count + 1
        if count > 5 then break end -- Safety
      end
      -- Should handle gracefully without infinite loop
      assert.is_true(count <= 5)
      assert.is_true(#results <= 5)
    end)
    
    it("should handle patterns that match empty strings", function()
      local results = {}
      local count = 0
      for match in string.gmatch("abc", "b*") do -- Can match empty string
        table.insert(results, match)
        count = count + 1
        if count > 10 then break end
      end
      -- Should not infinite loop
      assert.is_true(count <= 10)
      assert.is_true(#results <= 10)
    end)
    
    it("should handle matches at string boundaries", function()
      local results = {}
      for match in string.gmatch("hello", "^%w+") do -- Start anchor
        table.insert(results, match)
      end
      assert.are.same({"hello"}, results)
    end)
    
    it("should handle overlapping potential matches", function()
      local results = {}
      for match in string.gmatch("aaa", "aa") do
        table.insert(results, match)
      end
      -- Should find "aa" once, not overlapping matches
      assert.are.same({"aa"}, results)
    end)
    
  end)
  
  describe("Unicode and Multi-byte Character Handling", function()
    
    it("should handle unicode characters", function()
      local results = {}
      for word in string.gmatch("café naïve résumé", "%S+") do
        table.insert(results, word)
      end
      assert.are.same({"café", "naïve", "résumé"}, results)
    end)
    
    it("should handle multi-byte UTF-8 sequences", function()
      local emoji_string = "🚀 hello 🌟 world 💫"
      local results = {}
      for word in string.gmatch(emoji_string, "%w+") do
        table.insert(results, word)
      end
      assert.are.same({"hello", "world"}, results)
    end)
    
    it("should handle mixed ASCII and unicode", function()
      local mixed = "hello世界test"
      local results = {}
      for match in string.gmatch(mixed, "%w+") do
        table.insert(results, match)
      end
      -- Should find ASCII words
      assert.is_true(#results >= 2)
    end)
    
  end)
  
  describe("Complex Pattern Edge Cases", function()
    
    it("should handle escaped characters in patterns", function()
      local results = {}
      for match in string.gmatch("a.b*c+d?e", "%.") do -- Escaped dot
        table.insert(results, match)
      end
      assert.are.same({"."}, results)
    end)
    
    it("should handle character classes", function()
      local results = {}
      for match in string.gmatch("abc123XYZ", "[a-z]+") do
        table.insert(results, match)
      end
      assert.are.same({"abc"}, results)
    end)
    
    it("should handle negated character classes", function()
      local results = {}
      for match in string.gmatch("abc123", "[^%d]+") do
        table.insert(results, match)
      end
      assert.are.same({"abc"}, results)
    end)
    
    it("should handle complex nested patterns", function()
      local results = {}
      for match in string.gmatch("(test) [data]", "%b()") do -- Balanced parentheses
        table.insert(results, match)
      end
      assert.are.same({"(test)"}, results)
    end)
    
    it("should handle optional quantifiers", function()
      local results = {}
      for match in string.gmatch("color colour", "colou?r") do
        table.insert(results, match)
      end
      assert.are.same({"color", "colour"}, results)
    end)
    
  end)
  
  describe("Memory and Performance Edge Cases", function()
    
    it("should handle very large number of matches", function()
      local large_string = string.rep("a ", 1000) -- 1000 matches
      local count = 0
      for match in string.gmatch(large_string, "%w") do
        count = count + 1
      end
      assert.are.equal(1000, count)
    end)
    
    it("should handle patterns with many captures", function()
      -- Test more than 5 captures (our old optimization limit)
      local results = {}
      for a, b, c, d, e, f in string.gmatch("1,2,3,4,5,6", "(%d),(%d),(%d),(%d),(%d),(%d)") do
        table.insert(results, {a, b, c, d, e, f})
      end
      assert.are.same({{"1", "2", "3", "4", "5", "6"}}, results)
    end)
    
    it("should handle patterns with up to 10 captures", function()
      local results = {}
      for a, b, c, d, e, f, g, h, i, j in string.gmatch("1,2,3,4,5,6,7,8,9,0", "(%d),(%d),(%d),(%d),(%d),(%d),(%d),(%d),(%d),(%d)") do
        table.insert(results, {a, b, c, d, e, f, g, h, i, j})
      end
      assert.are.same({{"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"}}, results)
    end)
    
    it("should handle repeated pattern matching efficiently", function()
      local text = "word1 word2 word3 word4 word5"
      local count = 0
      for word in string.gmatch(text, "%w+") do
        count = count + 1
      end
      assert.are.equal(5, count)
    end)
    
  end)
  
  describe("Error Handling Edge Cases", function()
    
    it("should handle nil arguments gracefully", function()
      local success, err = pcall(function()
        string.gmatch(nil, "%w+")
      end)
      assert.is_false(success)
      assert.matches("bad argument #1 to 'gmatch'", err)
    end)
    
    it("should handle empty pattern correctly", function()
      local success, err = pcall(function()
        string.gmatch("test", "")
      end)
      assert.is_false(success)
      assert.matches("bad argument #2 to 'gmatch'", err)
    end)
    
    it("should handle malformed patterns", function()
      local success, err = pcall(function()
        string.gmatch("test", "[") -- Unclosed bracket
      end)
      assert.is_false(success)
      assert.matches("malformed pattern", err)
    end)
    
    it("should handle malformed character classes", function()
      local success, err = pcall(function()
        string.gmatch("test", "[abc") -- Unclosed bracket
      end)
      assert.is_false(success)
      assert.matches("malformed pattern", err)
    end)
    
    it("should handle invalid escape sequences gracefully", function()
      -- This should work - Lua patterns handle most escapes
      local results = {}
      for match in string.gmatch("test\\n", "\\") do
        table.insert(results, match)
      end
      assert.are.same({"\\"}, results)
    end)
    
  end)
  
  describe("Iterator State Edge Cases", function()
    
    it("should handle iterator called after completion", function()
      local iter = string.gmatch("abc", "%w")
      local results = {}
      
      -- Exhaust the iterator
      for match in iter do
        table.insert(results, match)
      end
      
      -- Calling again should return nil
      assert.is_nil(iter())
      assert.is_nil(iter())
    end)
    
    it("should handle multiple iterators on same string", function()
      local iter1 = string.gmatch("abc", "%w")
      local iter2 = string.gmatch("abc", "%w")
      
      assert.are.equal("a", iter1())
      assert.are.equal("a", iter2()) -- Should be independent
      assert.are.equal("b", iter1())
      assert.are.equal("b", iter2())
    end)
    
    it("should handle iterator state independence", function()
      local text = "one two three"
      local iter1 = string.gmatch(text, "%w+")
      local iter2 = string.gmatch(text, "%w+")
      
      local first1 = iter1()
      local first2 = iter2()
      local second1 = iter1()
      
      assert.are.equal("one", first1)
      assert.are.equal("one", first2)
      assert.are.equal("two", second1)
    end)
    
    it("should handle premature iterator termination", function()
      local iter = string.gmatch("one two three four", "%w+")
      
      -- Only consume first two matches
      local first = iter()
      local second = iter()
      
      assert.are.equal("one", first)
      assert.are.equal("two", second)
      
      -- Iterator should still work for remaining matches
      local third = iter()
      assert.are.equal("three", third)
    end)
    
  end)
  
  describe("Security Features", function()
    
    describe("Pattern Validation", function()
      
      it("should reject patterns with too many quantifiers", function()
        local success, err = pcall(function()
          string.gmatch("test", "%w*%w*%w*%w*%w*%w*") -- 6 quantifiers
        end)
        assert.is_false(success)
        assert.matches("pattern contains too many quantifiers", err)
      end)
      
      it("should allow patterns with acceptable number of quantifiers", function()
        local success = pcall(function()
          string.gmatch("test", "%w*%w*%w*%w*%w*") -- 5 quantifiers (limit)
        end)
        assert.is_true(success)
      end)
      
      it("should reject nested quantifiers .*.*", function()
        local success, err = pcall(function()
          string.gmatch("test", ".*.*")
        end)
        assert.is_false(success)
        assert.matches("nested quantifiers not allowed", err)
      end)
      
      it("should reject nested quantifiers .+.+", function()
        local success, err = pcall(function()
          string.gmatch("test", ".+.+")
        end)
        assert.is_false(success)
        assert.matches("nested quantifiers not allowed", err)
      end)
      
      it("should reject patterns with too many alternations", function()
        local pattern = "a|b|c|d|e|f|g|h|i|j|k|l" -- 11 pipes
        local success, err = pcall(function()
          string.gmatch("test", pattern)
        end)
        assert.is_false(success)
        assert.matches("pattern too complex", err)
      end)
      
      it("should allow patterns with acceptable alternations", function()
        local pattern = "a|b|c|d|e|f|g|h|i|j" -- 9 pipes (under limit)
        local success = pcall(function()
          string.gmatch("test", pattern)
        end)
        assert.is_true(success)
      end)
      
      it("should reject patterns designed to cause catastrophic backtracking", function()
        -- ReDoS patterns
        local success, err = pcall(function()
          string.gmatch("aaaaaaaaaaaaaaaaaaaaX", "(a+)+b")
        end)
        assert.is_false(success)
        assert.matches("catastrophic backtracking", err)
      end)
      
      it("should reject complex nested group patterns", function()
        local success, err = pcall(function()
          string.gmatch("test", "(a*)*b")
        end)
        assert.is_false(success)
        assert.matches("catastrophic backtracking", err)
      end)
      
    end)
    
    describe("Length Limits", function()
      
      it("should reject strings that are too long", function()
        local long_string = string.rep("a", 100001) -- Over 100KB limit
        local success, err = pcall(function()
          string.gmatch(long_string, "%w+")
        end)
        assert.is_false(success)
        assert.matches("string too long", err)
      end)
      
      it("should accept strings at the length limit", function()
        local max_string = string.rep("a", 100000) -- Exactly at 100KB limit
        local success = pcall(function()
          string.gmatch(max_string, "%w+")
        end)
        assert.is_true(success)
      end)
      
      it("should reject patterns that are too long", function()
        local long_pattern = string.rep("a", 501) -- Over 500 char limit
        local success, err = pcall(function()
          string.gmatch("test", long_pattern)
        end)
        assert.is_false(success)
        assert.matches("pattern too long", err)
      end)
      
      it("should accept patterns at the length limit", function()
        local max_pattern = string.rep("a", 500) -- Exactly at 500 char limit
        local success = pcall(function()
          string.gmatch("test", max_pattern)
        end)
        assert.is_true(success)
      end)
      
    end)
    
    describe("DoS Protection", function()
      
      it("should prevent infinite loops with iteration limit", function()
        -- Create a pattern that could potentially cause many iterations
        local test_string = string.rep("a", 1000)
        local iter = string.gmatch(test_string, "a?") -- This could match empty strings
        
        local count = 0
        local success, err = pcall(function()
          for match in iter do
            count = count + 1
            -- The iteration limit should kick in before we reach this high count
            if count > 15000 then
              break
            end
          end
        end)
        
        -- Should either complete successfully with reasonable count or hit iteration limit
        if not success then
          assert.matches("too many iterations", err)
        else
          assert.is_true(count <= 10000) -- Should not exceed our iteration limit
        end
      end)
      
      it("should ensure forward progress to prevent infinite loops", function()
        -- Test that we always advance position even with zero-width matches
        local results = {}
        local count = 0
        for match in string.gmatch("abc", "a?") do
          table.insert(results, match)
          count = count + 1
          if count > 10 then -- Safety break
            break
          end
        end
        
        -- Should have finite results, not infinite loop
        assert.is_true(#results <= 10)
        assert.is_true(count <= 10)
      end)
      
      it("should handle pathological zero-width patterns", function()
        local results = {}
        local count = 0
        local success, err = pcall(function()
          for match in string.gmatch("test", ".*") do
            table.insert(results, match)
            count = count + 1
            if count > 20 then break end -- Safety
          end
        end)
        
        -- Should either work with reasonable results or hit safety limits
        if success then
          assert.is_true(count <= 20)
        end
      end)
      
    end)
    
    describe("Performance Optimizations", function()
      
      it("should handle multiple captures efficiently", function()
        local results = {}
        for a, b, c, d, e in string.gmatch("1:2:3:4:5 6:7:8:9:0", "(%d):(%d):(%d):(%d):(%d)") do
          table.insert(results, {a, b, c, d, e})
        end
        assert.are.same({{"1", "2", "3", "4", "5"}, {"6", "7", "8", "9", "0"}}, results)
      end)
      
      it("should handle single captures efficiently", function()
        local results = {}
        for capture in string.gmatch("a1b2c3", "(%d)") do
          table.insert(results, capture)
        end
        assert.are.same({"1", "2", "3"}, results)
      end)
      
      it("should handle no captures efficiently", function()
        local results = {}
        for match in string.gmatch("hello world", "%w+") do
          table.insert(results, match)
        end
        assert.are.same({"hello", "world"}, results)
      end)
      
      it("should handle large input efficiently", function()
        local large_input = string.rep("word ", 5000) -- 5000 words
        local count = 0
        local start_time = os.clock()
        
        for word in string.gmatch(large_input, "%w+") do
          count = count + 1
        end
        
        local end_time = os.clock()
        local duration = end_time - start_time
        
        assert.are.equal(5000, count)
        -- Should complete in reasonable time (less than 1 second)
        assert.is_true(duration < 1.0)
      end)
      
    end)
    
  end)
end)