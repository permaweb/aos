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


local function findIndexByProp(array, prop, value)
  for index, object in ipairs(array) do
    if object[prop] == value then
      return index
    end
  end
  return nil
end

local function assertAddArgs(name, pattern, handle, maxRuns)
  assert(
    type(name) == 'string' and
    (type(pattern) == 'function' or type(pattern) == 'table' or type(pattern) == 'string'),
    'Invalid arguments given. Expected: \n' ..
    '\tname : string, ' ..
    '\tpattern : Action : string | MsgMatch : table,\n' ..
    '\t\tfunction(msg: Message) : {-1 = break, 0 = skip, 1 = continue},\n' ..
    '\thandle(msg : Message) : void) | Resolver,\n' ..
    '\tMaxRuns? : number | "inf" | nil')
end

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

-- Returns the next message that matches the pattern
-- This function uses Lua's coroutines under-the-hood to add a handler, pause,
-- and then resume the current coroutine. This allows us to effectively block
-- processing of one message until another is received that matches the pattern.
function handlers.receive(pattern)
  local self = coroutine.running()
  handlers.once(pattern, function (msg)
      coroutine.resume(self, msg)
  end)
  return coroutine.yield(pattern)
end

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
  handlers.add(name, pattern, handle, 1)
end

function handlers.add(...)
  local name, pattern, handle, maxRuns
  local args = select("#", ...)
  if args == 2 then
    name = select(1, ...)
    pattern = select(1, ...)
    handle = select(2, ...)
    maxRuns = nil
  elseif args == 3 then
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = nil
  else 
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = select(4, ...)
  end
  assertAddArgs(name, pattern, handle, maxRuns)
  
  handle = handlers.generateResolver(handle)
  
  -- update existing handler by name
  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    -- found update
    handlers.list[idx].pattern = pattern
    handlers.list[idx].handle = handle
    handlers.list[idx].maxRuns = maxRuns
  else
    -- not found then add    
    table.insert(handlers.list, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })

  end
  return #handlers.list
end

function handlers.append(...)
  local name, pattern, handle, maxRuns
  local args = select("#", ...)
  if args == 2 then
    name = select(1, ...)
    pattern = select(1, ...)
    handle = select(2, ...)
    maxRuns = nil
  elseif args == 3 then
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = nil
  else 
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = select(4, ...)
  end
  assertAddArgs(name, pattern, handle, maxRuns)
  
  handle = handlers.generateResolver(handle)
  -- update existing handler by name
  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    -- found update
    handlers.list[idx].pattern = pattern
    handlers.list[idx].handle = handle
    handlers.list[idx].maxRuns = maxRuns
  else
    
    table.insert(handlers.list, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
  end

  
end

function handlers.prepend(...)
  local name, pattern, handle, maxRuns
  local args = select("#", ...)
  if args == 2 then
    name = select(1, ...)
    pattern = select(1, ...)
    handle = select(2, ...)
    maxRuns = nil
  elseif args == 3 then
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = nil
  else 
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = select(4, ...)
  end
  assertAddArgs(name, pattern, handle, maxRuns)

  handle = handlers.generateResolver(handle)

  -- update existing handler by name
  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    -- found update
    handlers.list[idx].pattern = pattern
    handlers.list[idx].handle = handle
    handlers.list[idx].maxRuns = maxRuns
  else  
    table.insert(handlers.list, 1, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
  end

  
end

function handlers.before(handleName)
  assert(type(handleName) == 'string', 'Handler name MUST be a string')

  local idx = findIndexByProp(handlers.list, "name", handleName)
  return {
    add = function (name, pattern, handle, maxRuns) 
      assertAddArgs(name, pattern, handle, maxRuns)
      
      handle = handlers.generateResolver(handle)
      
      if idx then
        table.insert(handlers.list, idx, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
      end
      
    end
  }
end

function handlers.after(handleName)
  assert(type(handleName) == 'string', 'Handler name MUST be a string')
  local idx = findIndexByProp(handlers.list, "name", handleName)
  return {
    add = function (name, pattern, handle, maxRuns)
      assertAddArgs(name, pattern, handle, maxRuns)
      
      handle = handlers.generateResolver(handle)
      
      if idx then
        table.insert(handlers.list, idx + 1, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
      end
      
    end
  }

end

function handlers.remove(name)
  assert(type(name) == 'string', 'name MUST be string')
  if #handlers.list == 1 and handlers.list[1].name == name then
    handlers.list = {}
    
  end

  local idx = findIndexByProp(handlers.list, "name", name)
  table.remove(handlers.list, idx)
  
end

--- return 0 to not call handler, -1 to break after handler is called, 1 to continue
function handlers.evaluate(msg, env)
  local handled = false
  assert(type(msg) == 'table', 'msg is not valid')
  assert(type(env) == 'table', 'env is not valid')
  
  for _, o in ipairs(handlers.list) do
    if o.name ~= "_default" then
      local match = utils.matchesSpec(msg, o.pattern)
      if not (type(match) == 'number' or type(match) == 'string' or type(match) == 'boolean') then
        error("Pattern result is not valid, it MUST be string, number, or boolean")
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
        if match < 0 then
          handled = true
        end
        -- each handle function can accept, the msg, env
        local status, err = pcall(o.handle, msg, env)
        if not status then
          error(err)
        end
        -- remove handler if maxRuns is reached. maxRuns can be either a number or "inf"
        if o.maxRuns ~= nil and o.maxRuns ~= "inf" then
          o.maxRuns = o.maxRuns - 1
          if o.maxRuns == 0 then
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