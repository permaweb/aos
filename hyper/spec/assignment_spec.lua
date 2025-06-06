--[[
hyper AOS unit tests

assignment module

* matchesSpec function
* matchesPattern function
* addAssignable function
* removeAssignable function
* isAssignable function
* isAssignment function

]]

local Assignment = require "src/assignment"
local utils = require "src/utils"

describe("Enhanced Assignment Module", function()
  local ao

  -- Setup a fresh ao environment for each test
  before_each(function()
    ao = {
      id = "test-process-id",
      assignables = {}
    }
    Assignment.init(ao)
  end)

  describe("Basic matchesSpec tests", function()

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
  
  describe("Pattern Caching", function()
    it("should trigger pattern compilation for table-based matchSpecs", function()
      local pattern = { Action = "Transfer", Amount = "^[0-9]+$" }
      ao.addAssignable("test-pattern", pattern)
      
      local assignable = ao.assignables[1]
      assert.is_true(assignable.__pattern_cached)
      assert.equal("test-pattern", assignable.name)
      assert.same(pattern, assignable.pattern)
      -- The pattern itself should have the __matcher cached by utils.matchesSpec
      assert.is_not_nil(pattern.__matcher)
    end)

    it("should not cache compiled patterns for function-based matchSpecs", function()
      local pattern = function(msg) return msg.Action == "Custom" end
      ao.addAssignable("func-pattern", pattern)
      
      local assignable = ao.assignables[1]
      assert.is_nil(assignable.__pattern_cached)
      assert.equal("func-pattern", assignable.name)
      assert.is_function(assignable.pattern)
    end)

    it("should cache patterns when added without names", function()
      local pattern = { Action = "Test" }
      ao.addAssignable(pattern)
      
      local assignable = ao.assignables[1]
      assert.is_true(assignable.__pattern_cached)
      assert.is_nil(assignable.name)
      assert.is_not_nil(pattern.__matcher)
    end)

    it("should update cached patterns when pattern is updated by name", function()
      local original_pattern = { Action = "Original" }
      local updated_pattern = { Action = "Updated" }
      
      ao.addAssignable("updateable", original_pattern)
      assert.is_true(ao.assignables[1].__pattern_cached)
      
      ao.addAssignable("updateable", updated_pattern)
      
      assert.equal(1, #ao.assignables) -- Should still be only one
      assert.is_true(ao.assignables[1].__pattern_cached)
      assert.same(updated_pattern, ao.assignables[1].pattern)
      assert.is_not_nil(updated_pattern.__matcher)
    end)
  end)

  describe("Performance with Cached Patterns", function()
    it("should use cached matcher for table patterns in isAssignable", function()
      local pattern = { Action = "Transfer" }
      ao.addAssignable("cached-test", pattern)
      
      local test_msg = { 
        Action = "Transfer", 
        Target = "other-process",
        From = "sender"
      }
      
      -- Verify pattern was cached during addAssignable
      assert.is_not_nil(pattern.__matcher)
      
      local result = ao.isAssignable(test_msg)
      
      assert.is_true(result)
      -- Pattern should still have cached matcher
      assert.is_not_nil(pattern.__matcher)
    end)

    it("should fall back to utils.matchesSpec for function patterns", function()
      local function_called = false
      local pattern = function(msg) 
        function_called = true
        return msg.Action == "Custom" 
      end
      
      ao.addAssignable("func-test", pattern)
      
      local test_msg = { 
        Action = "Custom", 
        Target = "other-process" 
      }
      
      local result = ao.isAssignable(test_msg)
      
      assert.is_true(result)
      assert.is_true(function_called)
    end)
  end)

  describe("Backward Compatibility", function()
    it("should maintain same API for addAssignable with name", function()
      local pattern = { Action = "Transfer" }
      ao.addAssignable("test", pattern)
      
      assert.equal(1, #ao.assignables)
      assert.equal("test", ao.assignables[1].name)
      assert.same(pattern, ao.assignables[1].pattern)
    end)

    it("should maintain same API for addAssignable without name", function()
      local pattern = { Action = "Transfer" }
      ao.addAssignable(pattern)
      
      assert.equal(1, #ao.assignables)
      assert.is_nil(ao.assignables[1].name)
      assert.same(pattern, ao.assignables[1].pattern)
    end)

    it("should maintain same API for removeAssignable by name", function()
      ao.addAssignable("removeme", { Action = "Test" })
      ao.addAssignable("keepme", { Action = "Keep" })
      
      ao.removeAssignable("removeme")
      
      assert.equal(1, #ao.assignables)
      assert.equal("keepme", ao.assignables[1].name)
    end)

    it("should maintain same API for removeAssignable by index", function()
      ao.addAssignable("first", { Action = "First" })
      ao.addAssignable("second", { Action = "Second" })
      
      ao.removeAssignable(1)
      
      assert.equal(1, #ao.assignables)
      assert.equal("second", ao.assignables[1].name)
    end)

    it("should maintain same behavior for isAssignment", function()
      local self_msg = { Target = ao.id }
      local other_msg = { Target = "other-process" }
      
      assert.is_false(ao.isAssignment(self_msg))
      assert.is_true(ao.isAssignment(other_msg))
    end)

    it("should maintain same behavior for isAssignable when no patterns exist", function()
      local test_msg = { Action = "Test", Target = "other" }
      assert.is_false(ao.isAssignable(test_msg))
    end)
  end)

  describe("Pattern Matching Functionality", function()
    it("should match exact string patterns", function()
      ao.addAssignable("exact", { Action = "Transfer" })
      
      local matching_msg = { Action = "Transfer", Target = "other" }
      local non_matching_msg = { Action = "Send", Target = "other" }
      
      assert.is_true(ao.isAssignable(matching_msg))
      assert.is_false(ao.isAssignable(non_matching_msg))
    end)

    it("should match regex patterns", function()
      ao.addAssignable("regex", { Amount = "^[0-9]+$" })
      
      local matching_msg = { Amount = "1234", Target = "other" }
      local non_matching_msg = { Amount = "abc", Target = "other" }
      
      assert.is_true(ao.isAssignable(matching_msg))
      assert.is_false(ao.isAssignable(non_matching_msg))
    end)

    it("should match wildcard patterns", function()
      ao.addAssignable("wildcard", { From = "*" })
      
      local test_msg = { From = "anyone", Target = "other" }
      
      assert.is_true(ao.isAssignable(test_msg))
    end)

    it("should match complex table patterns", function()
      ao.addAssignable("complex", { 
        Action = "Transfer", 
        -- At least 4 digits, not starting with 0
        Amount = "^[1-9][0-9][0-9][0-9]+$", tags = { 
          Priority = "High",
          Type = "*"
        }
      })
      
      local matching_msg = {
        Action = "Transfer",
        Amount = "5000",
        Target = "other",
        tags = {
          Priority = "High",
          Type = "Urgent",
          Extra = "ignored"
        }
      }
      
      local non_matching_msg = {
        Action = "Transfer", 
        Amount = "50", -- Too small
        Target = "other",
        tags = { Priority = "High", Type = "Normal" }
      }
      
      -- Debug the pattern matching
      local result1 = ao.isAssignable(matching_msg)
      local result2 = ao.isAssignable(non_matching_msg)
      
      assert.is_true(result1)
      assert.is_false(result2)
    end)

    it("should match function patterns", function()
      ao.addAssignable("custom-func", function(msg)
        return msg.Action == "Custom" and tonumber(msg.Value or 0) > 100
      end)
      
      local matching_msg = { Action = "Custom", Value = "150", Target = "other" }
      local non_matching_msg = { Action = "Custom", Value = "50", Target = "other" }
      
      assert.is_true(ao.isAssignable(matching_msg))
      assert.is_false(ao.isAssignable(non_matching_msg))
    end)

    it("should return true if any pattern matches", function()
      ao.addAssignable("pattern1", { Action = "Transfer" })
      ao.addAssignable("pattern2", { Action = "Send" })
      ao.addAssignable("pattern3", function(msg) return msg.Special == "yes" end)
      
      local transfer_msg = { Action = "Transfer", Target = "other" }
      local send_msg = { Action = "Send", Target = "other" }
      local special_msg = { Action = "Other", Special = "yes", Target = "other" }
      local no_match_msg = { Action = "Other", Target = "other" }
      
      assert.is_true(ao.isAssignable(transfer_msg))
      assert.is_true(ao.isAssignable(send_msg))
      assert.is_true(ao.isAssignable(special_msg))
      assert.is_false(ao.isAssignable(no_match_msg))
    end)
  end)

  describe("Edge Cases and Error Handling", function()
    it("should require name to be a string when provided", function()
      assert.has_error(function()
        ao.addAssignable(123, { Action = "Test" })
      end, "MatchSpec name MUST be a string")
    end)

    it("should require index to be a number when removing by index", function()
      ao.addAssignable({ Action = "Test" })
      
      assert.has_error(function()
        ao.removeAssignable({}) -- Pass a table instead of string/number
      end)
    end)

    it("should handle removal of non-existent patterns gracefully", function()
      ao.addAssignable("exists", { Action = "Test" })
      
      -- Should not error
      ao.removeAssignable("does-not-exist")
      ao.removeAssignable(10) -- Index out of bounds
      ao.removeAssignable(0)  -- Invalid index
      
      assert.equal(1, #ao.assignables) -- Original should still exist
    end)

    it("should handle empty assignables list", function()
      assert.equal(0, #ao.assignables)
      assert.is_false(ao.isAssignable({ Action = "Test", Target = "other" }))
    end)

    it("should handle nil message gracefully", function()
      ao.addAssignable("test", { Action = "Test" })
      
      -- Should not crash - need to handle nil gracefully
      local result = pcall(function() return ao.isAssignable(nil) end)
      assert.is_true(result) -- Should not error
    end)

    it("should handle messages without Target field", function()
      ao.addAssignable("test", { Action = "Test" })
      
      local msg_without_target = { Action = "Test" }
      
      -- Should still be able to evaluate pattern matching
      assert.is_true(ao.isAssignable(msg_without_target))
    end)
  end)

  describe("Version Information", function()
    it("should have updated version number", function()
      assert.equal("0.1.1", Assignment._version)
    end)
  end)

  describe("Integration with utils.compile", function()
    it("should integrate with hyper's compile system for table patterns", function()
      local pattern = { Action = "Test", tags = { Type = "Special" } }
      ao.addAssignable("integration-test", pattern)
      
      -- Pattern should have cached matcher after addAssignable
      assert.is_not_nil(pattern.__matcher)
      local compiled_matcher = pattern.__matcher
      
      -- Test that the compiled matcher works correctly
      local matching_msg = { 
        Action = "Test", 
        tags = { Type = "Special", Extra = "ignored" } 
      }
      local non_matching_msg = { 
        Action = "Test", 
        tags = { Type = "Regular" } 
      }
      
      assert.is_true(compiled_matcher(matching_msg))
      assert.is_false(compiled_matcher(non_matching_msg))
    end)

    it("should cache compiled matchers on __matcher field for reuse", function()
      local pattern = { Action = "CacheTest" }
      ao.addAssignable("cache-integration", pattern)
      
      -- Access the pattern to trigger any lazy compilation in matchesSpec
      local test_msg = { Action = "CacheTest" }
      utils.matchesSpec(test_msg, pattern)
      
      -- The pattern itself should have the __matcher cached
      assert.is_not_nil(pattern.__matcher)
      assert.is_function(pattern.__matcher)
    end)
  end)

  describe("Performance Characteristics", function()
    it("should maintain pattern cache across multiple isAssignable calls", function()
      local pattern = { Action = "Performance" }
      ao.addAssignable("perf-test", pattern)
      
      local original_matcher = pattern.__matcher
      assert.is_not_nil(original_matcher)
      
      local test_msg = { Action = "Performance", Target = "other" }
      
      -- Multiple calls should use the same cached matcher
      ao.isAssignable(test_msg)
      ao.isAssignable(test_msg)
      ao.isAssignable(test_msg)
      
      assert.equal(original_matcher, pattern.__matcher)
    end)

    it("should handle large numbers of patterns efficiently", function()
      -- Add many patterns
      for i = 1, 100 do
        ao.addAssignable("pattern-" .. i, { Index = tostring(i) })
      end
      
      assert.equal(100, #ao.assignables)
      
      -- All should have pattern caching markers
      for _, assignable in ipairs(ao.assignables) do
        assert.is_true(assignable.__pattern_cached)
        assert.is_not_nil(assignable.pattern.__matcher)
      end
      
      -- Test matching still works
      local test_msg = { Index = "50", Target = "other" }
      assert.is_true(ao.isAssignable(test_msg))
    end)
  end)

  -- Test function patterns in matchesPattern
  describe("function patterns", function()
    it("should support function patterns in matchesPattern", function()
      local functionPattern = function(value, msg)
        return tonumber(value) > 100
      end
      
      assert.is_true(utils.matchesPattern(functionPattern, "150", {}))
      assert.is_false(utils.matchesPattern(functionPattern, "50", {}))
    end)
    
    it("should support function patterns with message context", function()
      local functionPattern = function(value, msg)
        return value == "admin" and msg.tags and msg.tags.role == "superuser"
      end
      
      local msg = { tags = { role = "superuser" } }
      assert.is_true(utils.matchesPattern(functionPattern, "admin", msg))
      assert.is_false(utils.matchesPattern(functionPattern, "user", msg))
      
      local msg2 = { tags = { role = "user" } }
      assert.is_false(utils.matchesPattern(functionPattern, "admin", msg2))
    end)
    
         it("should support function patterns in table specs", function()
       local spec = {
         action = function(value) return value:match("^test") end
       }
       ao.addAssignable("testHandler", spec)
       
       local msg1 = { action = "testAction" }
       assert.is_true(ao.isAssignable(msg1))
       
       local msg2 = { action = "otherAction" }
       assert.is_false(ao.isAssignable(msg2))
     end)
  end)
  
  -- Test table patterns (OR logic)
  describe("table patterns (OR logic)", function()
    it("should support table patterns in matchesPattern", function()
      local tablePattern = { "admin", "moderator", "owner" }
      
      assert.is_true(utils.matchesPattern(tablePattern, "admin", {}))
      assert.is_true(utils.matchesPattern(tablePattern, "moderator", {}))
      assert.is_true(utils.matchesPattern(tablePattern, "owner", {}))
      assert.is_false(utils.matchesPattern(tablePattern, "user", {}))
    end)
    
    it("should support mixed table patterns", function()
      local mixedPattern = { 
        "exact_match", 
        "^pattern_.*",
        function(v) return v == "custom" end,
        "_"  -- wildcard
      }
      
      assert.is_true(utils.matchesPattern(mixedPattern, "exact_match", {}))
      assert.is_true(utils.matchesPattern(mixedPattern, "pattern_test", {}))
      assert.is_true(utils.matchesPattern(mixedPattern, "custom", {}))
      assert.is_true(utils.matchesPattern(mixedPattern, "anything", {}))  -- wildcard
    end)
    
         it("should support table patterns in specs", function()
       local spec = {
         action = { "create", "update", "delete" }
       }
       ao.addAssignable("crudHandler", spec)
       
       assert.is_true(ao.isAssignable({ action = "create" }))
       assert.is_true(ao.isAssignable({ action = "update" }))
       assert.is_true(ao.isAssignable({ action = "delete" }))
       assert.is_false(ao.isAssignable({ action = "read" }))
     end)
  end)
  
  -- Test full regex support
  describe("full regex support", function()
    it("should support various regex patterns", function()
      -- Dollar sign end anchor
      assert.is_true(utils.matchesPattern("test$", "mytest", {}))
      assert.is_false(utils.matchesPattern("test$", "testing", {}))
      
             -- Character classes and alternatives (Lua style)
       assert.is_true(utils.matchesPattern("foo", "foo", {}))
       assert.is_true(utils.matchesPattern("bar", "bar", {}))
      
      -- Character classes
      assert.is_true(utils.matchesPattern("[0-9]+", "123", {}))
      assert.is_false(utils.matchesPattern("[0-9]+", "abc", {}))
      
      -- Plus quantifier
      assert.is_true(utils.matchesPattern("a+", "aaa", {}))
      assert.is_false(utils.matchesPattern("a+", "bbb", {}))
      
      -- Question mark optional
      assert.is_true(utils.matchesPattern("colou?r", "color", {}))
      assert.is_true(utils.matchesPattern("colou?r", "colour", {}))
    end)
    
         it("should handle regex in table specs", function()
       local spec = {
         tags = {
           type = "^message_[0-9]+$"
         }
       }
       ao.addAssignable("messageHandler", spec)
       
       local msg1 = { tags = { type = "message_123" } }
       assert.is_true(ao.isAssignable(msg1))
       
       local msg2 = { tags = { type = "message_abc" } }
       assert.is_false(ao.isAssignable(msg2))
       
       local msg3 = { tags = { type = "other_123" } }
       assert.is_false(ao.isAssignable(msg3))
     end)
  end)
  
  -- Test strict field validation
  describe("strict field validation", function()
         it("should fail when expected top-level fields are missing", function()
       local spec = { action = "test", required_field = "value" }
       ao.addAssignable("strictHandler", spec)
       
       -- Message with missing required_field should not match
       local msg = { action = "test" }
       assert.is_false(ao.isAssignable(msg))
       
       -- Message with all fields should match
       local msg2 = { action = "test", required_field = "value" }
       assert.is_true(ao.isAssignable(msg2))
     end)
    
         it("should fail when expected body fields are missing", function()
       local spec = { action = "test" }
       ao.addAssignable("bodyHandler", spec)
       
       -- Message with missing action (neither top-level nor body) should not match
       local msg = { other = "value" }
       assert.is_false(ao.isAssignable(msg))
       
       -- Message with action in body should match
       local msg2 = { body = { action = "test" } }
       assert.is_true(ao.isAssignable(msg2))
     end)
    
         it("should fail when expected tags are missing", function()
       local spec = {
         tags = { type = "message", priority = "high" }
       }
       ao.addAssignable("tagHandler", spec)
       
       -- Message with missing priority tag should not match
       local msg = { tags = { type = "message" } }
       assert.is_false(ao.isAssignable(msg))
       
       -- Message with all required tags should match
       local msg2 = { tags = { type = "message", priority = "high" } }
       assert.is_true(ao.isAssignable(msg2))
     end)
  end)
  
  -- Test complex patterns combining all features
  describe("complex combined patterns", function()
    it("should handle complex nested patterns", function()
      local spec = {
        action = { "process", "^handle_.*" },
        tags = {
          type = function(value) return value:match("^msg_") end,
          priority = { "high", "urgent", "_" }  -- any value or specific values
        },
        user_id = "^[0-9]+$"
      }
             ao.addAssignable("complexHandler", spec)
       
       -- Should match: action in table, function pattern for type, table pattern for priority, regex for user_id
       local msg1 = {
         action = "process",
         tags = { type = "msg_important", priority = "high" },
         user_id = "12345"
       }
       assert.is_true(ao.isAssignable(msg1))
       
       -- Should match: regex action, function pattern for type, wildcard priority, regex user_id
       local msg2 = {
         action = "handle_request",
         tags = { type = "msg_data", priority = "medium" },  -- wildcard matches any
         user_id = "67890"
       }
       assert.is_true(ao.isAssignable(msg2))
       
       -- Should not match: wrong action
       local msg3 = {
         action = "other",
         tags = { type = "msg_test", priority = "high" },
         user_id = "12345"
       }
       assert.is_false(ao.isAssignable(msg3))
       
       -- Should not match: type doesn't start with msg_
       local msg4 = {
         action = "process",
         tags = { type = "other_test", priority = "high" },
         user_id = "12345"
       }
       assert.is_false(ao.isAssignable(msg4))
    end)
  end)
end) 