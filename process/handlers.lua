local handlers = { _version = "0.0.5" }

handlers.utils = require('.handlers-utils')
handlers.list = {}
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
            if Handlers.matchesPattern(msg, matchSpec) then
                return func(msg)
            end
        end
    end
  end
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

function handlers.add(name, pattern, handle, maxRuns)
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

function handlers.append(name, pattern, handle, maxRuns)
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

function handlers.prepend(name, pattern, handle, maxRuns)
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
  assert(type(name) == 'string', 'Handler name MUST be a string')
  if #handlers.list == 1 and handlers.list[1].name == name then
    handlers.list = {}
    
  end

  local idx = findIndexByProp(handlers.list, "name", name)
  table.remove(handlers.list, idx)
  
end

function handlers.matchesPattern(msg, pattern)
  if type(pattern) == 'function' then
    return pattern(msg)
  -- If the pattern is a table, step through every key/value pair in the pattern and check if the msg matches
  -- Supported match types:
  --   - Exact string match
  --   - Lua gmatch string
  --   - '_' (wildcard: Message has tag, but can be any value)
  --   - Function execution on the tag, optionally using the msg as the second argument
  end
  if type(pattern) == 'table' then
    for key, patternMatchSpec in pairs(pattern) do
      local matched = false
      -- If the key is not in the message, then it does not match
      if(not msg[key]) then
        return false
      end
      -- if the patternMatchSpec is a wildcard, then it always matches
      if patternMatchSpec == '_' then
        matched = true
      end
      -- if the patternMatchSpec is a function, then it is executed on the tag value
      if type(patternMatchSpec) == "function" then
        if patternMatchSpec(msg[key], msg) then
          matched = true
        else
          return false
        end
      end
      -- if the patternMatchSpec is a string, check it for special symbols (less `-` alone)
      -- and exact string match mode
      if not matched and string.match(patternMatchSpec, "[%^%$%(%)%%%.%[%]%*%+%?]") then
        if string.match(msg[key], patternMatchSpec) then
          matched = true
        end
      else
        if msg[key] == patternMatchSpec then
          matched = true
        end
      end
      -- if the patternMatchSpec is not matched, then the msg does not match
      if not matched then
        return false
      end
    end
    return true
  end
  if type(pattern) == 'string' and msg.Action == pattern then
    return true
  end
  return false
end

--- return 0 to not call handler, -1 to break after handler is called, 1 to continue
function handlers.evaluate(msg, env)
  local handled = false
  assert(type(msg) == 'table', 'msg is not valid')
  assert(type(env) == 'table', 'env is not valid')

  for _, o in ipairs(handlers.list) do
    if o.name ~= "_default" then
      local match = handlers.matchesPattern(msg, o.pattern)
      if not (type(match) == 'number' or type(match) == 'string' or type(match) == 'boolean') then
        error({message = "pattern result is not valid, it MUST be string, number, or boolean"})
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
          ao.outbox.Error = { err = err }
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