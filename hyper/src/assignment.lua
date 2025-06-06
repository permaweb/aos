--- The Assignment module provides functionality for handling assignments. Returns the Assignment table.
-- @module assignment

--- The Assignment module
-- @table Assignment
-- @field _version The version number of the assignment module
-- @field init The init function
local Assignment = { _version = "0.1.2" } -- Version bump for assignment processing
local utils = require 'src.utils'
local json = require 'src.json'


--- Implement assignable polyfills on ao.
-- Creates addAssignable, removeAssignable, isAssignment, and isAssignable fields on ao.
-- @function init
-- @tparam {table} ao The ao environment object
-- @see ao.addAssignable
-- @see ao.removeAssignable
-- @see ao.isAssignment
-- @see ao.isAssignable
function Assignment.init (ao)
  -- Find the index of an object in an array by a given property
  -- @lfunction findIndexByProp
  -- @tparam {table} array The array to search
  -- @tparam {string} prop The property to search by
  -- @tparam {any} value The value to search for
  -- @treturn {number|nil} The index of the object, or nil if not found
  local function findIndexByProp(array, prop, value)
    for index, object in ipairs(array) do
      if object[prop] == value then return index end
    end

    return nil
  end

  -- Filter message based on exclude list while preserving Owner
  local function filterMessage(msg, excludeList)
    excludeList = excludeList or {}
    local filtered = {}
    
    -- Always preserve these critical fields
    local preserveFields = { "Id", "Target", "Owner", "From", "Timestamp" }
    
    for key, value in pairs(msg) do
      local shouldInclude = true
      
      -- Check if field is in exclude list
      for _, excludeField in ipairs(excludeList) do
        if key == excludeField then
          shouldInclude = false
          break
        end
      end
      
      -- Always preserve critical fields (override exclude)
      for _, preserveField in ipairs(preserveFields) do
        if key == preserveField then
          shouldInclude = true
          break
        end
      end
      
      if shouldInclude then
        filtered[key] = value
      end
    end
    
    return filtered
  end

  ao.assignables = ao.assignables or {}
  ao.messages = ao.messages or {}

  ao.addAssignable = ao.addAssignable or function (...)
    local name = nil
    local matchSpec = nil
    local idx = nil

    -- Initialize the parameters based on arguments
    if select("#", ...) == 1 then
      matchSpec = select(1, ...)
    else
      name = select(1, ...)
      matchSpec = select(2, ...)
      assert(type(name) == 'string', 'MatchSpec name MUST be a string')
    end

    if name then idx = findIndexByProp(ao.assignables, "name", name) end

    -- Create assignable entry with pattern caching support
    local assignable_entry = { 
      pattern = matchSpec, 
      name = name
    }
    
    -- Pre-trigger compilation for table patterns using utils.matchesSpec
    -- This will cause the pattern to be compiled and cached on the __matcher field
    if type(matchSpec) == "table" then
      -- Create a dummy message to trigger compilation and caching
      local dummy_msg = {}
      utils.matchesSpec(dummy_msg, matchSpec)
      assignable_entry.__pattern_cached = true
    end

    if idx ~= nil and idx > 0 then
      -- found update
      ao.assignables[idx] = assignable_entry
    else
      -- append the new assignable, including potentially nil name
      table.insert(ao.assignables, assignable_entry)
    end
  end

  ao.removeAssignable = ao.removeAssignable or function (name)
    local idx = nil

    if type(name) == 'string' then 
      idx = findIndexByProp(ao.assignables, "name", name)
    else
      assert(type(name) == 'number', 'index MUST be a number')
      idx = name
    end

    if idx == nil or idx <= 0 or idx > #ao.assignables then return end

    table.remove(ao.assignables, idx)
  end

  ao.isAssignment = ao.isAssignment or function (msg) 
    return msg.Target ~= ao.id 
  end

  ao.isAssignable = ao.isAssignable or function (msg)
    -- Handle nil message gracefully
    if not msg then return false end
    
    for _, assignable in pairs(ao.assignables) do
      -- Use utils.matchesSpec which will automatically use cached compiled patterns
      -- The caching happens internally on the pattern's __matcher field
      if utils.matchesSpec(msg, assignable.pattern) then 
        return true 
      end
    end

    -- If assignables is empty, the the above loop will noop,
    -- and this expression will execute.
    --
    -- In other words, all msgs are not assignable, by default.
    return false
  end

  -- Process assignment messages that match our patterns
  ao.processAssignment = ao.processAssignment or function (msg, excludeList)
    -- Only process if it's an assignment we care about
    if not ao.isAssignment(msg) or not ao.isAssignable(msg) then
      return false
    end
    
    -- Filter the message (exclude unwanted fields, preserve Owner)
    local filteredMsg = filterMessage(msg, excludeList)
    
    -- Store the filtered message
    ao.messages[msg.Id] = filteredMsg
    
    return true
  end

  -- Handle remote assignable management via messages
  ao.handleAssignableActions = ao.handleAssignableActions or function (msg)
    local action = msg.Tags and msg.Tags.Action
    if not action then return false end
    
    if action == "AddAssignable" then
      local name = msg.Tags.Name
      local pattern = nil
      
      if msg.Data then
        local success, result = pcall(json.decode, msg.Data)
        if success then
          pattern = result
        end
      end
      
      if pattern then
        if name then
          ao.addAssignable(name, pattern)
        else
          ao.addAssignable(pattern)
        end
        return true
      end
      
    elseif action == "RemoveAssignable" then
      local name = msg.Tags.Name
      local index = msg.Tags.Index and tonumber(msg.Tags.Index)
      
      if name then
        ao.removeAssignable(name)
        return true
      elseif index then
        ao.removeAssignable(index)
        return true
      end
    end
    
    return false
  end
end

return Assignment
