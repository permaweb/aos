--[[
hyper AOS unit tests

handlers module

* add function
* append function
* prepend function
* remove function
* evaluate function
* once function
* generateResolver function
]]

describe("handlers", function()
  
  local handlers
  local mockUtils, mockHandlersUtils
  
  before_each(function()
    -- Mock dependencies
    mockUtils = {
      matchesSpec = function(msg, spec) return true end,
      reduce = function(fn, acc, tbl) return acc end
    }
    
    mockHandlersUtils = {}
    
    -- Mock package.loaded
    package.loaded['.utils'] = mockUtils
    package.loaded['.handlers-utils'] = mockHandlersUtils
    
    -- Clear any existing global Handlers
    _G.Handlers = nil
    
    -- Require the module after mocking
    handlers = require('src/handlers')
  end)
  
  after_each(function()
    -- Clean up package.loaded
    package.loaded['.utils'] = nil
    package.loaded['.handlers-utils'] = nil
    package.loaded['src/handlers'] = nil
    _G.Handlers = nil
  end)
  
  describe("initialization", function()
    
    it("should have version 0.0.5", function()
      assert.are.equal("0.0.5", handlers._version)
    end)
    
    it("should initialize empty list", function()
      assert.is_not_nil(handlers.list)
      assert.are.equal("table", type(handlers.list))
      assert.are.equal(0, #handlers.list)
    end)
    
    it("should initialize onceNonce to 0", function()
      assert.are.equal(0, handlers.onceNonce)
    end)
    
    it("should preserve existing Handlers.list if Handlers exists", function()
      _G.Handlers = { list = { { name = "existing" } } }
      package.loaded['src/handlers'] = nil
      local newHandlers = require('src/handlers')
      
      assert.are.equal(1, #newHandlers.list)
      assert.are.equal("existing", newHandlers.list[1].name)
    end)
    
  end)
  
  describe("generateResolver", function()
    
    it("should return function when given function", function()
      local testFunc = function() return "test" end
      local resolver = handlers.generateResolver(testFunc)
      
      assert.are.equal("function", type(resolver))
      assert.are.equal("test", resolver())
    end)
    
    it("should handle table of patterns", function()
      local resolveSpec = {
        ["test-pattern"] = function() return "matched" end
      }
      
      local resolver = handlers.generateResolver(resolveSpec)
      local result = resolver({ action = "test" })
      
      assert.are.equal("matched", result)
    end)
    
  end)
  
  describe("add", function()
    
    before_each(function()
      handlers.list = {}
    end)
    
    it("should add handler with 2 args (name, handle)", function()
      local testHandle = function() return "test" end
      handlers.add("test-handler", testHandle)
      
      assert.are.equal(1, #handlers.list)
      assert.are.equal("test-handler", handlers.list[1].name)
      assert.are.equal("test-handler", handlers.list[1].pattern)
      assert.is_nil(handlers.list[1].maxRuns)
    end)
    
    it("should add handler with 3 args (name, pattern, handle)", function()
      local testPattern = function() return true end
      local testHandle = function() return "test" end
      handlers.add("test-handler", testPattern, testHandle)
      
      assert.are.equal(1, #handlers.list)
      assert.are.equal("test-handler", handlers.list[1].name)
      assert.are.equal(testPattern, handlers.list[1].pattern)
    end)
    
    it("should add handler with 4 args (name, pattern, handle, maxRuns)", function()
      local testPattern = function() return true end
      local testHandle = function() return "test" end
      handlers.add("test-handler", testPattern, testHandle, 5)
      
      assert.are.equal(1, #handlers.list)
      assert.are.equal("test-handler", handlers.list[1].name)
      assert.are.equal(5, handlers.list[1].maxRuns)
    end)
    
    it("should update existing handler by name", function()
      local testHandle1 = function() return "test1" end
      local testHandle2 = function() return "test2" end
      
      handlers.add("test-handler", testHandle1)
      handlers.add("test-handler", testHandle2)
      
      assert.are.equal(1, #handlers.list)
    end)
    
    it("should validate arguments", function()
      assert.has_error(function()
        handlers.add(123, function() end) -- invalid name type
      end)
      
      assert.has_error(function()
        handlers.add("test", 123, function() end) -- invalid pattern type  
      end)
    end)
    
  end)
  
  describe("append", function()
    
    before_each(function()
      handlers.list = {}
      handlers.add("first", function() end)
    end)
    
    it("should add handler to end of list", function()
      handlers.append("second", function() end)
      
      assert.are.equal(2, #handlers.list)
      assert.are.equal("second", handlers.list[2].name)
    end)
    
  end)
  
  describe("prepend", function()
    
    before_each(function()
      handlers.list = {}
      handlers.add("first", function() end)
    end)
    
    it("should add handler to beginning of list", function()
      handlers.prepend("zeroth", function() end)
      
      assert.are.equal(2, #handlers.list)
      assert.are.equal("zeroth", handlers.list[1].name)
      assert.are.equal("first", handlers.list[2].name)
    end)
    
  end)
  
  describe("remove", function()
    
    before_each(function()
      handlers.list = {}
      handlers.add("first", function() end)
      handlers.add("second", function() end)
      handlers.add("third", function() end)
    end)
    
    it("should remove handler by name", function()
      handlers.remove("second")
      
      assert.are.equal(2, #handlers.list)
      assert.are.equal("first", handlers.list[1].name)
      assert.are.equal("third", handlers.list[2].name)
    end)
    
    it("should remove handler successfully", function()
      local initialCount = #handlers.list
      handlers.remove("second")
      
      assert.are.equal(initialCount - 1, #handlers.list)
    end)
    
    it("should return nil if handler not found", function()
      local removed = handlers.remove("nonexistent")
      
      assert.is_nil(removed)
    end)
    
  end)
  
  describe("once", function()
    
    before_each(function()
      handlers.list = {}
      -- Reset onceNonce to get predictable names
      handlers.onceNonce = 0
    end)
    
    it("should add handler with maxRuns of 1", function()
      handlers.once("test-once", function() end)
      
      assert.are.equal(1, #handlers.list)
      assert.are.equal(1, handlers.list[1].maxRuns)
    end)
    
    it("should generate name when not provided", function()
      -- Reset nonce first
      handlers.onceNonce = 0
      handlers.once(function() end, function() end)
      
      assert.are.equal(1, #handlers.list)
      assert.are.equal("_once_0", handlers.list[1].name)
      assert.are.equal(1, handlers.onceNonce)
    end)
    
    it("should increment onceNonce for generated names", function()
      -- Save current state and reset completely
      local originalNonce = handlers.onceNonce
      local originalList = handlers.list
      handlers.list = {}
      handlers.onceNonce = 0
      
      handlers.once(function() end, function() end)
      handlers.once(function() end, function() end)
      
      assert.are.equal(2, #handlers.list)
      -- Since prepend inserts at position 1, the second handler comes first
      assert.are.equal("_once_1", handlers.list[1].name)
      assert.are.equal("_once_0", handlers.list[2].name)
      assert.are.equal(2, handlers.onceNonce)
      
      -- Restore original state
      handlers.onceNonce = originalNonce
      handlers.list = originalList
    end)
    
  end)
  
  describe("evaluate", function()
    
    before_each(function()
      handlers.list = {}
    end)
    
    it("should call matching handler", function()
      local called = false
      local testPattern = function() return true end
      local testHandle = function() called = true end
      
      handlers.add("test", testPattern, testHandle)
      handlers.evaluate({ action = "test" }, { process = {} })
      
      assert.is_true(called)
    end)
    
    it("should not call non-matching handler", function()
      local called = false
      local testPattern = function() return false end
      local testHandle = function() called = true end
      
      -- Mock matchesSpec to return false for this test
      mockUtils.matchesSpec = function(msg, spec) return false end
      
      handlers.add("test", testPattern, testHandle)
      -- Add a default handler to avoid the nil error
      handlers.add("_default", function() return true end, function() end)
      
      handlers.evaluate({ action = "test" }, { process = {} })
      
      assert.is_false(called)
    end)
    
    it("should handle handler returning -1 (break)", function()
      local firstCalled = false
      local secondCalled = false
      
      handlers.add("first", function() return true end, function() 
        firstCalled = true
        return -1
      end)
      handlers.add("second", function() return true end, function() 
        secondCalled = true
      end)
      
      handlers.evaluate({ action = "test" }, { process = {} })
      
      assert.is_true(firstCalled)
      assert.is_false(secondCalled)
    end)
    
    it("should handle handler returning 0 (skip)", function()
      local firstCalled = false
      local secondCalled = false
      
      -- Mock matchesSpec to return specific values based on pattern 
      mockUtils.matchesSpec = function(msg, pattern)
        if type(pattern) == "function" then
          return pattern()
        end
        return true
      end
      
      handlers.add("first", function() return 0 end, function() 
        firstCalled = true
        return 0
      end)
      handlers.add("second", function() return true end, function() 
        secondCalled = true
      end)
      
      handlers.evaluate({ action = "test" }, { process = {} })
      
      assert.is_false(firstCalled) -- Should not be called because pattern returns 0
      assert.is_true(secondCalled)
    end)
    
    it("should remove handler after maxRuns reached", function()
      local callCount = 0
      handlers.add("test", function() return true end, function() 
        callCount = callCount + 1
      end, 2)
      -- Add a default handler to avoid the nil error
      handlers.add("_default", function() return true end, function() end)
      
      handlers.evaluate({ action = "test" }, { process = {} })
      handlers.evaluate({ action = "test" }, { process = {} })
      handlers.evaluate({ action = "test" }, { process = {} })
      
      assert.are.equal(2, callCount)
      -- Handler should be removed from list after maxRuns
      local found = false
      for _, h in ipairs(handlers.list) do
        if h.name == "test" then found = true end
      end
      assert.is_false(found)
    end)
    
  end)
  
end)