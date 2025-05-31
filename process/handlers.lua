--- The Handlers library provides a flexible way to manage and execute a series of handlers based on patterns. Each handler consists of a pattern function, a handle function, and a name. This library is suitable for scenarios where different actions need to be taken based on varying input criteria. Returns the handlers table.
-- @module handlers

--- The handlers table
-- @table handlers
-- @field _version The version number of the handlers module
-- @field list The list of handlers
-- @field coroutines The coroutines of the handlers
-- @field onceNonce The nonce for the once handlers
-- @field utils The handlers-utils module
-- @field generateResolver The generateResolver function
-- @field receive The receive function
-- @field once The once function
-- @field add The add function
-- @field append The append function
-- @field prepend The prepend function
-- @field setActive The handler activation function
-- @field advanced The advanced handler function
-- @field remove The remove function
-- @field evaluate The evaluate function
local handlers = { _version = "0.0.5" }
local coroutine = require('coroutine')
local utils = require('.utils')

handlers.utils = require('.handlers-utils')
-- if update we need to keep defined handlers
if Handlers then
  handlers.list = Handlers.list or {}
  handlers.coroutines = Handlers.coroutines or {}
else
  handlers.list = {}
  handlers.coroutines = {}

end
handlers.onceNonce = 0

--- Given an array, a property name, and a value, returns the index of the object in the array that has the property with the value.
-- @lfunction findIndexByProp
-- @tparam {table[]} array The array to search through
-- @tparam {string} prop The property name to check
-- @tparam {any} value The value to check for in the property
-- @treturn {number | nil} The index of the object in the array that has the property with the value, or nil if no such object is found
local function findIndexByProp(array, prop, value)
  for index, object in ipairs(array) do
    if object[prop] == value then
      return index
    end
  end
  return nil
end

--- Given a resolver specification, returns a resolver function.
-- @function generateResolver
-- @tparam {table | function} resolveSpec The resolver specification
-- @treturn {function} A resolver function
function handlers.generateResolver(resolveSpec)
  return function(msg)
    -- If the resolver is a single function, call it.
    -- Else, find the first matching pattern (by its matchSpec), and exec.
    if type(resolveSpec) == "function" then
      return resolveSpec(msg)
    else
      for matchSpec, func in pairs(resolveSpec) do
        if utils.matchesSpec(msg, matchSpec) then
          return func(msg)
        end
      end
    end
  end
end

--- Given a pattern, returns the next message that matches the pattern.
-- This function uses Lua's coroutines under-the-hood to add a handler, pause,
-- and then resume the current coroutine. This allows us to effectively block
-- processing of one message until another is received that matches the pattern.
-- @function receive
-- @tparam {table | function} pattern The pattern to check for in the message
function handlers.receive(pattern)
  local self = coroutine.running()
  handlers.once(pattern, function (msg)
    -- If the result of the resumed coroutine is an error then we should bubble it up to the process
    local _, success, errmsg = coroutine.resume(self, msg)
    assert(success, errmsg)
  end)
  return coroutine.yield(pattern)
end

--- Given a name, a pattern, and a handle, adds a handler to the list.
-- If name is not provided, "_once_" prefix plus onceNonce will be used as the name.
-- Adds handler with maxRuns of 1 such that it will only be called once then removed from the list.
-- @function once
-- @tparam {string} name The name of the handler
-- @tparam {table | function | string} pattern The pattern to check for in the message
-- @tparam {function} handle The function to call if the pattern matches
function handlers.once(...)
  local name, pattern, handle
  if select("#", ...) == 3 then
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
  else
    name = "_once_" .. tostring(handlers.onceNonce)
    handlers.onceNonce = handlers.onceNonce + 1
    pattern = select(1, ...)
    handle = select(2, ...)
  end
  handlers.prepend(name, pattern, handle, 1)
end

--- Given a name, a pattern, and a handle, adds a handler to the list.
-- @function add
-- @tparam {string} name The name of the handler
-- @tparam {table | function | string} pattern The pattern to check for in the message
-- @tparam {function} handle The function to call if the pattern matches
-- @tparam {number | string | nil} maxRuns The maximum number of times the handler should run, or nil if there is no limit
function handlers.add(...)
  -- select arguments based on the amount of arguments provided
  local args = select("#", ...)
  local name = select(1, ...)
  local pattern = select(1, ...)
  local handle = select(2, ...)

  local maxRuns

  if args >= 3 then
    pattern = select(2, ...)
    handle = select(3, ...)
  end
  if args >= 4 then maxRuns = select(4, ...) end

  -- configure handler
  return handlers.advanced({
    name = name,
    pattern = pattern,
    handle = handle,
    maxRuns = maxRuns
  })
end

--- Appends a new handler to the end of the handlers list.
-- @function append
-- @tparam {string} name The name of the handler
-- @tparam {table | function | string} pattern The pattern to check for in the message
-- @tparam {function} handle The function to call if the pattern matches
-- @tparam {number | string | nil} maxRuns The maximum number of times the handler should run, or nil if there is no limit
handlers.append = handlers.add

--- Prepends a new handler to the beginning of the handlers list.
-- @function prepend
-- @tparam {string} name The name of the handler
-- @tparam {table | function | string} pattern The pattern to check for in the message
-- @tparam {function} handle The function to call if the pattern matches
-- @tparam {number | string | nil} maxRuns The maximum number of times the handler should run, or nil if there is no limit
function handlers.prepend(...)
  -- select arguments based on the amount of arguments provided
  local args = select("#", ...)
  local name = select(1, ...)
  local pattern = select(1, ...)
  local handle = select(2, ...)

  local maxRuns

  if args >= 3 then
    pattern = select(2, ...)
    handle = select(3, ...)
  end
  if args >= 4 then maxRuns = select(4, ...) end

  -- configure handler
  return handlers.advanced({
    name = name,
    pattern = pattern,
    handle = handle,
    maxRuns = maxRuns,
    position = 'prepend'
  })
end

--- Returns an object that allows adding a new handler before a specified handler.
-- @function before
-- @tparam {string} handleName The name of the handler before which the new handler will be added
-- @treturn {table} An object with an `add` method to insert the new handler
function handlers.before(handleName)
  assert(type(handleName) == 'string', 'Handler name MUST be a string')

  return {
    add = function (name, pattern, handle, maxRuns)
      -- configure handler
      return handlers.advanced({
        name = name,
        pattern = pattern,
        handle = handle,
        maxRuns = maxRuns,
        position = {
          type = 'before',
          target = handleName
        }
      })
    end
  }
end

--- Returns an object that allows adding a new handler after a specified handler.
-- @function after
-- @tparam {string} handleName The name of the handler after which the new handler will be added
-- @treturn {table} An object with an `add` method to insert the new handler
function handlers.after(handleName)
  assert(type(handleName) == 'string', 'Handler name MUST be a string')

  return {
    add = function (name, pattern, handle, maxRuns)
      -- configure handler
      return handlers.advanced({
        name = name,
        pattern = pattern,
        handle = handle,
        maxRuns = maxRuns,
        position = {
          type = 'after',
          target = handleName
        }
      })
    end
  }

end

--- Allows activating/deactivating a handler
-- @function setActive
-- @tparam {string} name The target handler's name
-- @tparam {boolean} status The handlers active status
function handlers.setActive(name, status)
  assert(type(status) == 'boolean', 'Invalid status: must be a boolean')

  -- find handler
  local idx = findIndexByProp(handlers.list, 'name', name)

  -- not found
  if idx == nil or idx <= 0 then return end

  -- reverse provided status
  handlers.list[idx].inactive = not status
end

--- Allows creating and adding a handler with advanced options using a simple configuration table
-- @function advanced
-- @tparam {table} config The new handler's configuration
function handlers.advanced(config)
  -- validate handler config
  assert(type(config.name) == 'string', 'Invalid handler name: must be a string')
  assert(
    type(config.pattern) == 'function' or type(config.pattern) == 'table' or type(config.pattern) == 'string',
    'Invalid pattern: must be a function, a table or a string'
  )

  if config.position ~= nil then
    assert(
      type(config.position) == 'table' or config.position == 'append' or config.position == 'prepend',
      'Invalid position: must be a table or "append"/"prepend"'
    )

    if type(config.position) == 'table' then
      assert(
        config.position.type == 'append' or config.position.type == 'prepend' or config.position.type == 'before' or config.position.type == 'after',
        'Invalid position.type: must be one of ("append", "prepend", "before", "after")'
      )
      assert(
        config.position.target == nil or type(config.position.target) == 'string',
        'Invalid position.target: must be a string (handler name)'
      )
    end
  end

  assert(
    type(config.handle) == 'function' or type(config.handle) == 'table',
    'Invalid handle: must be a function or a table of resolvers'
  )
  assert(
    config.runType == nil or config.runType == 'continue' or config.runType == 'break' or config.runType == 1 or config.runType == -1,
    'Invalid runType: must be "continue"/1 or "break"/-1'
  )
  assert(
    config.maxRuns == nil or type(config.maxRuns) == 'number',
    "Invalid maxRuns: must be an integer"
  )
  assert(
    config.errorHandler == nil or type(config.errorHandler) == 'function',
    "Invalid error handler: must be a function"
  )
  assert(
    config.onRemove == nil or type(config.onRemove) == 'function',
    "Invalid onRemove: must be a function"
  )
  assert(
    config.inactive == nil or type(config.inactive) == 'boolean',
    'Invalid inactive: must be a boolean'
  )

  if config.timeout then
    assert(
      type(config.timeout) == 'table' or type(config.timeout) == 'number',
      'Invalid timeout: must be a table or a number'
    )

    if type(config.timeout) == 'table' then
      assert(
        config.timeout.type == 'milliseconds' or config.timeout.type == 'blocks',
        'Invalid timeout.type: must be of ("milliseconds" or "blocks")'
      )
      assert(
        type(config.timeout.value) == 'number',
        'Invalid timeout.value: must be an integer'
      )
    end
  end

  -- generate resolver for the handler
  config.handle = handlers.generateResolver(config.handle)

  -- handle timeout when it is a number (blocks)
  if type(config.timeout) == 'number' then
    config.timeout = {
      type = 'blocks',
      value = config.timeout
    }
  end

  -- if the handler already exists, find it and update
  local idx = findIndexByProp(handlers.list, 'name', config.name)

  if idx ~= nil and idx > 0 then
    -- found a handler to update
    handlers[idx] = config
  else
    -- a handler with this name doesn't exist yet, so we add it
    --
    -- calculate the position the handler should be added at
    -- (by default it's the end of the list)
    idx = #handlers.list + 1
    if config.position and config.position ~= 'append' then
      if config.position == 'prepend' or config.position.type == 'prepend' then
        idx = 1
      elseif type(config.position) == 'table' and config.position.type ~= 'append' then
        idx = findIndexByProp(handlers.list, 'name', config.position.target)

        if config.position.type == 'after' and idx and idx > 0 then
          idx = idx + 1
        end

        if not idx or idx <= 0 then
          return #handlers.list
        end
      end
    end

    -- add handler
    table.insert(handlers.list, idx, config)
  end

  return #handlers.list
end

--- Removes a handler from the handlers list by name.
-- @function remove
-- @tparam {string} name The name of the handler to be removed
function handlers.remove(name)
  assert(type(name) == 'string', 'name MUST be string')
  if #handlers.list == 1 and handlers.list[1].name == name then
    if handlers.list[1].onRemove ~= nil then
      handlers.list[1].onRemove("user-remove")
    end
    handlers.list = {}
  end

  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    if handlers.list[idx].onRemove ~= nil then
      handlers.list[idx].onRemove("user-remove")
    end
    table.remove(handlers.list, idx)
  end
end

--- Evaluates each handler against a given message and environment. Handlers are called in the order they appear in the handlers list.
-- Return 0 to not call handler, -1 to break after handler is called, 1 to continue
-- @function evaluate
-- @tparam {table} msg The message to be processed by the handlers.
-- @tparam {table} env The environment in which the handlers are executed.
-- @treturn The response from the handler(s). Returns a default message if no handler matches.
function handlers.evaluate(msg, env)
  local handled = false
  assert(type(msg) == 'table', 'msg is not valid')
  assert(type(env) == 'table', 'env is not valid')

  for _, o in ipairs(handlers.list) do
    if o.name ~= "_default" and not o.inactive then
      local match = utils.matchesSpec(msg, o.pattern)
      if not (type(match) == 'number' or type(match) == 'string' or type(match) == 'boolean') then
        error("Pattern result is not valid, it MUST be string, number, or boolean")
      end

      -- ensure the handler hasn't timed out yet
      if o.timeout then
        -- remove handler if it timed out
        if (o.timeout.type == 'milliseconds' and o.timeout.value < msg.Timestamp) or (o.timeout.type == 'blocks' and o.timeout.value < msg["Block-Height"]) then
          if o.onRemove ~= nil then
            o.onRemove("timeout")
            o.onRemove = nil
          end
          handlers.remove(o.name)
          match = 0
        end
      end

      -- handle boolean returns
      if type(match) == "boolean" and match == true then
        match = -1
      elseif type(match) == "boolean" and match == false then
        match = 0
      end

      -- handle string returns
      if type(match) == "string" then
        if match == "continue" then
          match = 1
        elseif match == "break" then
          match = -1
        else
          match = 0
        end
      end

      if match ~= 0 then
        -- the pattern matched, now we overwrite it with the
        -- handler's "runType" configuration, if there's any
        if o.runType ~= nil then
          if type(o.runType) == 'number' then
            match = o.runType
          else
            match = o.runType == 'continue' and 1 or -1
          end
        end

        if match < 0 then
          handled = true
        end
        -- each handle function can accept, the msg, env
        local status, err = pcall(o.handle, msg, env)
        if not status then
          if not o.errorHandler then error(err)
          else
            -- allow error handler to override the default
            -- handler behavior (break/continue)
            local errorHandlerRes = o.errorHandler(msg, env, err)

            if errorHandlerRes ~= nil then
              if type(errorHandlerRes) ~= "number" then
                match = errorHandlerRes == "break" and -1 or 1
              elseif errorHandlerRes == 1 or errorHandlerRes == -1 then
                match = errorHandlerRes
              end
            end
          end
        end
        -- remove handler if maxRuns is reached. maxRuns can be either a number or "inf"
        if o.maxRuns ~= nil and o.maxRuns ~= "inf" then
          o.maxRuns = o.maxRuns - 1
          if o.maxRuns == 0 then
            if o.onRemove ~= nil then
              o.onRemove("expired")
              o.onRemove = nil
            end
            handlers.remove(o.name)
          end
        end
      end
      if match < 0 then
        return handled
      end
    end
  end
  -- do default
  if not handled then
    local idx = findIndexByProp(handlers.list, "name", "_default")
    handlers.list[idx].handle(msg,env)
  end
end

return handlers
