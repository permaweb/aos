--[[
hyper AOS unit tests

process module

* handle function
* Version function
]]

describe("process", function()
  
  local process
  local mockAo, mockHandlers, mockUtils, mockState, mockEval, mockDefault, mockJson
  
  before_each(function()
    -- Mock all dependencies
    mockAo = {
      init = function() end,
      clearOutbox = function() end,
      result = function(r) return r end,
      send = function(msg) return msg end
    }
    
    mockHandlers = {
      add = function() end,
      remove = function() end,
      evaluate = function() return true end
    }
    
    mockUtils = {
      map = function(fn, tbl) 
        for i, v in ipairs(tbl or {}) do
          fn(v)
        end
      end,
      keys = function(tbl)
        local keys = {}
        for k, _ in pairs(tbl or {}) do
          table.insert(keys, k)
        end
        return keys
      end
    }
    
    mockState = {
      reset = function(logs) return {} end,
      init = function() end,
      isTrusted = function() return true end,
      getFrom = function() return "test-from" end,
      insertInbox = function() end
    }
    
    mockEval = function() return function() end end
    mockDefault = function() return function() end end
    mockJson = {
      decode = function(str) return {} end
    }
    
    -- Set up global mocks
    _G.ao = mockAo
    _G.Handlers = mockHandlers
    _G.Utils = mockUtils
    _G.HandlerPrintLogs = {}
    _G.Owner = "test-owner"
    _G.Colors = {
      red = "", green = "", gray = "", reset = ""
    }
    _G.Prompt = function() return "aos> " end
    _G.Errors = {}
    _G.Version = function() print("version: " .. (process and process._version or "2.0.7")) end
    
    -- Mock package.loaded
    package.loaded['.ao'] = mockAo
    package.loaded['.handlers'] = mockHandlers
    package.loaded['.utils'] = mockUtils
    package.loaded['.dump'] = {}
    package.loaded['.state'] = mockState
    package.loaded['.eval'] = mockEval
    package.loaded['.default'] = mockDefault
    package.loaded['.json'] = mockJson
    
    -- Require the module after mocking
    process = require('src/process')
  end)
  
  after_each(function()
    -- Clean up globals
    _G.ao = nil
    _G.Handlers = nil
    _G.Utils = nil
    _G.HandlerPrintLogs = nil
    _G.Owner = nil
    _G.Colors = nil
    _G.Prompt = nil
    _G.Errors = nil
    _G.Version = nil
    
    -- Clean up package.loaded
    package.loaded['.ao'] = nil
    package.loaded['.handlers'] = nil
    package.loaded['.utils'] = nil
    package.loaded['.dump'] = nil
    package.loaded['.state'] = nil
    package.loaded['.eval'] = nil
    package.loaded['.default'] = nil
    package.loaded['.json'] = nil
    package.loaded['src/process'] = nil
  end)
  
  describe("handle", function()
    
    local mockReq, mockBase
    
    before_each(function()
      mockReq = {
        ['block-timestamp'] = "1234567890",
        body = {
          action = "Test",
          data = "test data",
          ['Content-Type'] = "text/plain"
        }
      }
      
      mockBase = {
        process = { id = "test-process" }
      }
    end)
    
    it("should return untrusted message result when not trusted", function()
      mockState.isTrusted = function() return false end
      
      local result = process.handle(mockReq, mockBase)
      
      assert.are.equal("Message is not trusted.", result.Output.data)
    end)
    
    it("should decode JSON data when Content-Type is application/json", function()
      local decodeCalled = false
      mockJson.decode = function(str)
        decodeCalled = true
        return { decoded = true }
      end
      
      mockReq.body['Content-Type'] = 'application/json'
      mockReq.body.data = '{"test": true}'
      
      process.handle(mockReq, mockBase)
      
      assert.is_true(decodeCalled)
    end)
    
    it("should set os.time from block-timestamp", function()
      process.handle(mockReq, mockBase)
      
      assert.are.equal(1234567890, os.time())
    end)
    
    it("should add reply function to request", function()
      local replyFn = nil
      mockHandlers.evaluate = function(req)
        replyFn = req.reply
        return true
      end
      
      process.handle(mockReq, mockBase)
      
      assert.is_not_nil(replyFn)
      assert.are.equal("function", type(replyFn))
    end)
    
    it("should handle Eval action correctly", function()
      mockReq.body.action = "Eval"
      
      local result = process.handle(mockReq, mockBase)
      
      assert.is_not_nil(result.Output)
      assert.are.equal("aos> ", result.Output.prompt)
    end)
    
    it("should handle non-Eval action correctly", function()
      mockReq.body.action = "Balance"
      
      local result = process.handle(mockReq, mockBase)
      
      assert.is_not_nil(result.Output)
      assert.are.equal("aos> ", result.Output.prompt)
      assert.is_true(result.Output.print)
    end)
    
    it("should handle handler evaluation errors", function()
      mockHandlers.evaluate = function()
        error("Test error")
      end
      
      local result = process.handle(mockReq, mockBase)
      
      assert.is_not_nil(result.Output)
      assert.is_true(string.find(result.Output.data, "error") ~= nil)
    end)
    
    it("should handle Eval errors differently", function()
      mockReq.body.action = "Eval"
      mockHandlers.evaluate = function()
        error("Eval test error")
      end
      
      local result = process.handle(mockReq, mockBase)
      
      assert.is_not_nil(result.Error)
      assert.is_true(string.find(result.Error, "Eval test error") ~= nil)
    end)
    
    it("should initialize ao and state", function()
      local aoInitCalled = false
      local stateInitCalled = false
      
      mockAo.init = function() aoInitCalled = true end
      mockState.init = function() stateInitCalled = true end
      
      process.handle(mockReq, mockBase)
      
      assert.is_true(aoInitCalled)
      assert.is_true(stateInitCalled)
    end)
    
    it("should clear outbox", function()
      local clearOutboxCalled = false
      mockAo.clearOutbox = function() clearOutboxCalled = true end
      
      process.handle(mockReq, mockBase)
      
      assert.is_true(clearOutboxCalled)
    end)
    
    it("should add and remove _eval and _default handlers", function()
      local addedHandlers = {}
      local removedHandlers = {}
      
      mockHandlers.add = function(name)
        table.insert(addedHandlers, name)
      end
      
      mockHandlers.remove = function(name)
        table.insert(removedHandlers, name)
      end
      
      process.handle(mockReq, mockBase)
      
      -- Helper function
      local function contains(tbl, item)
        for _, v in ipairs(tbl) do
          if v == item then return true end
        end
        return false
      end
      
      assert.is_true(contains(addedHandlers, "_eval"))
      assert.is_true(contains(addedHandlers, "_default"))
      assert.is_true(contains(removedHandlers, "_eval"))
      assert.is_true(contains(removedHandlers, "_default"))
    end)
    
    it("should create reply function with correct properties", function()
      local sentMessage = nil
      mockAo.send = function(msg)
        sentMessage = msg
        return msg
      end
      
      mockHandlers.evaluate = function(req)
        req.reply({ data = "test reply" })
        return true
      end
      
      process.handle(mockReq, mockBase)
      
      assert.is_not_nil(sentMessage)
      assert.are.equal("test reply", sentMessage.data)
      assert.are.equal("test-from", sentMessage.target)
    end)
    
  end)
  
  describe("Version", function()
    
    it("should print version", function()
      local printOutput = ""
      local originalPrint = print
      print = function(str) printOutput = str end
      
      -- The Version function from process.lua
      local function Version()
        print("version: " .. process._version)
      end
      
      Version()
      
      print = originalPrint
      assert.is_true(string.find(printOutput, "version:") ~= nil)
      assert.is_true(string.find(printOutput, "2.0.7") ~= nil)
    end)
    
  end)
  
end)

-- Helper function for testing
local utils = {
  contains = function(tbl, item)
    for _, v in ipairs(tbl) do
      if v == item then return true end
    end
    return false
  end
}