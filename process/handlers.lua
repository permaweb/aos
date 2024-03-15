local handlers = { _version = "0.0.3" }

handlers.utils = require('.handlers-utils')
handlers.list = {}

local function findIndexByProp(array, prop, value)
  for index, object in ipairs(array) do
    if object[prop] == value then
      return index
    end
  end
  return nil
end

function handlers.add(name, pattern, handle)
  assert(type(name) == 'string' and type(pattern) == 'function' and  type(handle) == 'function', 'invalid arguments: handler.add(name : string, pattern : function(msg: Message) : {-1 = break, 0 = skip, 1 = continue}, handle(msg : Message) : void)') 
  assert(type(name) == 'string', 'name MUST be string')
  assert(type(pattern) == 'function', 'pattern MUST be function')
  assert(type(handle) == 'function', 'handle MUST be function')
  
  
  -- update existing handler by name
  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    -- found update
    handlers.list[idx].pattern = pattern
    handlers.list[idx].handle = handle
  else
    -- not found then add    
    table.insert(handlers.list, { pattern = pattern, handle = handle, name = name })

  end
end


function handlers.append(name, pattern, handle)
  assert(type(name) == 'string' and type(pattern) == 'function' and  type(handle) == 'function', 'invalid arguments: handler.append(name : string, pattern : function(msg: Message) : {-1 = break, 0 = skip, 1 = continue}, handle(msg : Message) : void)') 
  assert(type(name) == 'string', 'name MUST be string')
  assert(type(pattern) == 'function', 'pattern MUST be function')
  assert(type(handle) == 'function', 'handle MUST be function')
  
    -- update existing handler by name
  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    -- found update
    handlers.list[idx].pattern = pattern
    handlers.list[idx].handle = handle
  else
    
    table.insert(handlers.list, { pattern = pattern, handle = handle, name = name })
  end

  
end

function handlers.prepend(name, pattern, handle) 
  assert(type(name) == 'string' and type(pattern) == 'function' and  type(handle) == 'function', 'invalid arguments: handler.prepend(name : string, pattern : function(msg: Message) : {-1 = break, 0 = skip, 1 = continue}, handle(msg : Message) : void)') 
  assert(type(name) == 'string', 'name MUST be string')
  assert(type(pattern) == 'function', 'pattern MUST be function')
  assert(type(handle) == 'function', 'handle MUST be function')
  

  -- update existing handler by name
  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    -- found update
    handlers.list[idx].pattern = pattern
    handlers.list[idx].handle = handle
  else  
    table.insert(handlers.list, 1, { pattern = pattern, handle = handle, name = name })
  end

  
end

function handlers.before(handleName)
  assert(handleName ~= nil, 'invalid arguments: handlers.before(name : string) : { add = function(name, pattern, handler)}')
  assert(type(handleName) == 'string', 'name MUST be string')

  local idx = findIndexByProp(handlers.list, "name", handleName)
  return {
    add = function (name, pattern, handle) 
      assert(type(name) == 'string' and type(pattern) == 'function' and  type(handle) == 'function', 'invalid arguments: handler.before("foo").add(name : string, pattern : function(msg: Message) : {-1 = break, 0 = skip, 1 = continue}, handle(msg : Message) : void)') 
      assert(type(name) == 'string', 'name MUST be string')
      
      assert(type(pattern) == 'function', 'pattern MUST be function')
      assert(type(handle) == 'function', 'handle MUST be function')
      
      if idx then
        table.insert(handlers.list, idx, { pattern = pattern, handle = handle, name = name })
      end
      
    end
  }
end

function handlers.after(handleName)
  assert(handleName ~= nil, 'invalid arguments: handlers.after(name : string) : { add = function(name, pattern, handler)}')
  assert(type(handleName) == 'string', 'name MUST be string')
  local idx = findIndexByProp(handlers.list, "name", handleName)
  return { 
    add = function (name, pattern, handle)
      assert(type(name) == 'string' and type(pattern) == 'function' and  type(handle) == 'function', 'invalid arguments: handler.after("foo").add(name : string, pattern : function(msg: Message) : {-1 = break, 0 = skip, 1 = continue}, handle(msg : Message) : void)') 

      assert(type(name) == 'string', 'name MUST be string')
      assert(type(pattern) == 'function', 'pattern MUST be function')
      assert(type(handle) == 'function', 'handle MUST be function')
      
      if idx then
        table.insert(handlers.list, idx + 1, { pattern = pattern, handle = handle, name = name })
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
      local match = o.pattern(msg)
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