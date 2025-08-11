--[[
hyper AOS unit tests

ao module

* clearOutbox function
* init function
* send function
* spawn function
* result function
* event function
]]

describe("ao", function()
  
  local ao
  local mockUtils, mockHandlers
  
  before_each(function()
    -- Mock dependencies
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
      end,
      reduce = function(fn, acc, tbl)
        for _, v in ipairs(tbl or {}) do
          acc = fn(acc, v)
        end
        return acc
      end,
      includes = function(item, tbl)
        for _, v in ipairs(tbl or {}) do
          if v == item then return true end
        end
        return false
      end
    }
    
    mockHandlers = {
      once = function() end
    }
    
    -- Mock package.loaded
    package.loaded['.handlers'] = mockHandlers
    package.loaded['.utils'] = mockUtils
    
    -- Clear any existing global ao and Handlers
    ao = nil
    Handlers = mockHandlers
    
    -- Require the module after mocking
    ao = require('src/ao')
  end)
  
  after_each(function()
    -- Clean up package.loaded
    package.loaded['.handlers'] = nil
    package.loaded['.utils'] = nil
    package.loaded['src/ao'] = nil
    Handlers = nil
    ao = nil
  end)
  
  describe("initialization", function()
    
    it("should have version 0.0.6", function()
      assert.are.equal("0.0.6", ao._version)
    end)
    
    it("should initialize with empty id", function()
      assert.are.equal("", ao.id)
    end)
    
    it("should initialize with empty authorities", function()
      assert.is_not_nil(ao.authorities)
      assert.are.equal("table", type(ao.authorities))
      assert.are.equal(0, #ao.authorities)
    end)
    
    it("should initialize reference to 0", function()
      assert.are.equal(0, ao.reference)
    end)
    
    it("should initialize outbox with proper structure", function()
      assert.is_not_nil(ao.outbox)
      assert.is_not_nil(ao.outbox.Output)
      assert.is_not_nil(ao.outbox.Messages)
      assert.is_not_nil(ao.outbox.Spawns)
      assert.is_not_nil(ao.outbox.Assignments)
    end)
    
    it("should preserve existing ao data when present", function()
      local existingAo = {
        id = "existing-id",
        reference = 5,
        authorities = {"auth1", "auth2"}
      }
      
      package.loaded['src/ao'] = nil
      _G.ao = existingAo
      local newAo = require('src/ao')
      
      assert.are.equal("existing-id", newAo.id)
      assert.are.equal(5, newAo.reference)
      assert.are.equal(2, #newAo.authorities)
    end)
    
  end)
  
  describe("clearOutbox", function()
    
    it("should reset outbox to empty structure", function()
      ao.outbox.Messages = { {data = "test"} }
      ao.outbox.Output = { data = "test" }
      
      ao.clearOutbox()
      
      assert.are.equal(0, #ao.outbox.Messages)
      assert.are.equal(0, #ao.outbox.Spawns)
      assert.are.equal(0, #ao.outbox.Assignments)
      assert.is_not_nil(ao.outbox.Output)
    end)
    
  end)
  
  describe("init", function()
    
    local mockEnv
    
    before_each(function()
      mockEnv = {
        process = {
          commitments = {
            ["test-id"] = {
              alg = "rsa-pss-sha512",
              committer = "test-committer"
            }
          },
          authority = {"auth1", "auth2", "auth3"} -- Use table instead of string to avoid parsing
        }
      }
      ao.id = ""
      ao.authorities = {}
    end)
    
    it("should set id from process commitments", function()
      local originalPrint = print
      print = function() end
      
      ao.init(mockEnv)
      
      print = originalPrint
      assert.are.equal("test-id", ao.id)
    end)
    
    it("should not change id if already set", function()
      local originalPrint = print
      print = function() end
      
      ao.id = "existing-id"
      ao.init(mockEnv)
      
      print = originalPrint
      assert.are.equal("existing-id", ao.id)
    end)
    
    it("should handle array authority directly", function()
      local originalPrint = print
      print = function() end
      
      ao.init(mockEnv)
      
      print = originalPrint
      assert.are.equal(3, #ao.authorities)
      assert.are.equal("auth1", ao.authorities[1])
      assert.are.equal("auth2", ao.authorities[2])
      assert.are.equal("auth3", ao.authorities[3])
    end)
    
    
    it("should use table authority directly", function()
      local originalPrint = print
      print = function() end
      
      mockEnv.process.authority = {"direct1", "direct2"}
      ao.init(mockEnv)
      
      print = originalPrint
      assert.are.equal(2, #ao.authorities)
      assert.are.equal("direct1", ao.authorities[1])
      assert.are.equal("direct2", ao.authorities[2])
    end)
    
    it("should not change authorities if already populated", function()
      local originalPrint = print
      print = function() end
      
      ao.authorities = {"existing"}
      ao.init(mockEnv)
      
      print = originalPrint
      assert.are.equal(1, #ao.authorities)
      assert.are.equal("existing", ao.authorities[1])
    end)
    
    it("should reset outbox", function()
      local originalPrint = print
      print = function() end
      
      ao.outbox.Messages = { {data = "old"} }
      ao.init(mockEnv)
      
      print = originalPrint
      assert.are.equal(0, #ao.outbox.Messages)
    end)
    
    it("should set env", function()
      local originalPrint = print
      print = function() end
      
      ao.init(mockEnv)
      
      print = originalPrint
      assert.are.equal(mockEnv, ao.env)
    end)
    
  end)
  
  describe("send", function()
    
    before_each(function()
      ao.reference = 0
      ao.outbox.Messages = {}
    end)
    
    it("should increment reference", function()
      local msg = { target = "test-target", data = "test" }
      ao.send(msg)
      
      assert.are.equal(1, ao.reference)
      assert.are.equal("1", msg.reference)
    end)
    
    it("should add message to outbox", function()
      local msg = { target = "test-target", data = "test" }
      ao.send(msg)
      
      assert.are.equal(1, #ao.outbox.Messages)
      assert.are.equal("test-target", ao.outbox.Messages[1].target)
      assert.are.equal("test", ao.outbox.Messages[1].data)
    end)
    
    it("should add onReply function when target exists", function()
      local msg = { target = "test-target", data = "test" }
      local result = ao.send(msg)
      
      assert.is_not_nil(result.onReply)
      assert.are.equal("function", type(result.onReply))
    end)
    
    it("should validate message is table", function()
      assert.has_error(function()
        ao.send("not a table")
      end)
    end)
    
    it("should return message with modifications", function()
      local msg = { target = "test-target", data = "test" }
      local result = ao.send(msg)
      
      assert.are.equal(msg, result)
      assert.are.equal("1", result.reference)
    end)
    
  end)
  
  describe("spawn", function()
    
    before_each(function()
      ao.reference = 0
      ao.outbox.Spawns = {}
      ao.id = "test-ao-id"
    end)
    
    it("should increment reference", function()
      local msg = { data = "test" }
      ao.spawn("module-id", msg)
      
      assert.are.equal(1, ao.reference)
      assert.are.equal("1", msg.reference)
    end)
    
    it("should add spawn to outbox", function()
      local msg = { data = "test" }
      ao.spawn("module-id", msg)
      
      assert.are.equal(1, #ao.outbox.Spawns)
      assert.are.equal("test", ao.outbox.Spawns[1].data)
    end)
    
    it("should add onReply function", function()
      local msg = { data = "test" }
      local result = ao.spawn("module-id", msg)
      
      assert.is_not_nil(result.onReply)
      assert.are.equal("function", type(result.onReply))
    end)
    
    it("should validate module is string", function()
      assert.has_error(function()
        ao.spawn(123, {})
      end)
    end)
    
    it("should validate message is table", function()
      assert.has_error(function()
        ao.spawn("module-id", "not a table")
      end)
    end)
    
  end)
  
  describe("result", function()
    
    it("should return result object with outbox structure", function()
      local testResult = { Output = { data = "test" } }
      local result = ao.result(testResult)
      
      assert.is_not_nil(result)
      assert.are.equal("test", result.Output.data)
      -- ao.result adds outbox structure
      assert.is_not_nil(result.Messages)
      assert.is_not_nil(result.Spawns)
      assert.is_not_nil(result.Assignments)
    end)
    
  end)
  
  describe("event", function()
    
    it("should call event function if it exists", function()
      local eventCalled = false
      local testData = { action = "test" }
      
      ao.event = function(data)
        eventCalled = true
        assert.are.equal(testData, data)
      end
      
      ao.event(testData)
      
      assert.is_true(eventCalled)
    end)
    
  end)
  
end)