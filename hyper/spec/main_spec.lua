--[[
hyper AOS unit tests

main module

* compute function
]]
local main = require('src/main')

describe("main", function()
  
  describe("compute", function()
    
    local mockBase, mockReq, mockOpts
    
    before_each(function()
      -- Mock the global ao object
      _G.ao = {
        event = function() end
      }
      
      -- Mock the process module
      package.loaded['.process'] = {
        handle = function(req, base)
          return {
            Output = { data = "test output" },
            Messages = {
              { target = "test-target", data = "test message 1" },
              { target = "test-target2", data = "test message 2" }
            }
          }
        end
      }
      
      mockBase = {
        process = { id = "test-process-id" },
        results = {}
      }
      
      mockReq = {
        body = { action = "Test", data = "test data" }
      }
      
      mockOpts = {}
    end)
    
    after_each(function()
      -- Clean up global ao
      _G.ao = nil
      -- Clean up mocked modules
      package.loaded['.process'] = nil
    end)
    
    it("should return base object with results", function()
      local result = compute(mockBase, mockReq, mockOpts)
      
      assert.is_not_nil(result)
      assert.are.equal(mockBase, result)
      assert.is_not_nil(result.results)
    end)
    
    it("should set info to 'hyper-aos'", function()
      local result = compute(mockBase, mockReq, mockOpts)
      
      assert.are.equal("hyper-aos", result.results.info)
    end)
    
    it("should initialize empty outbox", function()
      local result = compute(mockBase, mockReq, mockOpts)
      
      assert.is_not_nil(result.results.outbox)
      assert.are.equal("table", type(result.results.outbox))
    end)
    
    it("should set output from process results", function()
      local result = compute(mockBase, mockReq, mockOpts)
      
      assert.are.equal("test output", result.results.output.data)
    end)
    
    it("should populate outbox with indexed messages", function()
      local result = compute(mockBase, mockReq, mockOpts)
      
      assert.are.equal("test message 1", result.results.outbox["1"].data)
      assert.are.equal("test message 2", result.results.outbox["2"].data)
      assert.are.equal("test-target", result.results.outbox["1"].target)
      assert.are.equal("test-target2", result.results.outbox["2"].target)
    end)
    
    it("should handle empty messages array", function()
      -- Override process mock to return empty messages
      package.loaded['.process'] = {
        handle = function(req, base)
          return {
            Output = { data = "test output" },
            Messages = {}
          }
        end
      }
      
      local result = compute(mockBase, mockReq, mockOpts)
      
      assert.are.equal(0, #result.results.outbox)
    end)
    
    it("should call ao.event with process and request body", function()
      local eventCalls = {}
      _G.ao.event = function(data)
        table.insert(eventCalls, data)
      end
      
      compute(mockBase, mockReq, mockOpts)
      
      assert.are.equal(2, #eventCalls)
      assert.are.equal(mockBase.process, eventCalls[1])
      assert.are.equal(mockReq.body, eventCalls[2])
    end)
    
    it("should call process.handle with correct parameters", function()
      local handleCalls = {}
      package.loaded['.process'] = {
        handle = function(req, base)
          table.insert(handleCalls, {req = req, base = base})
          return {
            Output = { data = "test" },
            Messages = {}
          }
        end
      }
      
      compute(mockBase, mockReq, mockOpts)
      
      assert.are.equal(1, #handleCalls)
      assert.are.equal(mockReq, handleCalls[1].req)
      assert.are.equal(mockBase, handleCalls[1].base)
    end)
    
    it("should handle process.handle returning nil Messages", function()
      package.loaded['.process'] = {
        handle = function(req, base)
          return {
            Output = { data = "test output" },
            Messages = nil
          }
        end
      }
      
      -- Should handle nil Messages gracefully
      local result = compute(mockBase, mockReq, mockOpts)
      assert.is_not_nil(result)
      assert.is_not_nil(result.results)
      assert.are.equal("test output", result.results.output.data)
    end)
    
  end)
  
end)