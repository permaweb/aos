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

function handlers.append(pattern, handle, name) 
  assert(type(pattern) == 'function', 'pattern MUST be function')
  assert(type(handle) == 'function', 'handle MUST be function')
  assert(type(name) == 'string', 'name MUST be string')
  
  table.insert(handlers.list, { pattern = pattern, handle = handle, name = name })
end

function handlers.prepend(pattern, handle, name) 
  assert(type(pattern) == 'function', 'pattern MUST be function')
  assert(type(handle) == 'function', 'handle MUST be function')
  assert(type(name) == 'string', 'name MUST be string')

  table.insert(handlers.list, 1, { pattern = pattern, handle = handle, name = name })
end

function handlers.before(handleName)
  assert(type(handleName) == 'string', 'name MUST be string')

  local idx = findIndexByProp(handlers.list, "name", handleName)
  return {
    add = function (pattern, handle, name) 
      assert(type(pattern) == 'function', 'pattern MUST be function')
      assert(type(handle) == 'function', 'handle MUST be function')
      assert(type(name) == 'string', 'name MUST be string')
      
      if idx then
        table.insert(handlers.list, idx, { pattern = pattern, handle = handle, name = name })
      end
      return nil
    end
  }
end

function handlers.after(handleName)
  assert(type(handleName) == 'string', 'name MUST be string')
  local idx = findIndexByProp(handlers.list, "name", handleName)
  return { 
    add = function (pattern, handle, name)
      assert(type(pattern) == 'function', 'pattern MUST be function')
      assert(type(handle) == 'function', 'handle MUST be function')
      assert(type(name) == 'string', 'name MUST be string')

      if idx then
        table.insert(handlers.list, idx + 1, { pattern = pattern, handle = handle, name = name })
      end
      return nil
    end
  }

end

function handlers.remove(name)
  assert(type(name) == 'string', 'name MUST be string')
  if #handlers.list == 1 and handlers.list[1].name == name then
    handlers.list = {}
    return
  end

  local idx = findIndexByProp(handlers.list, "name", name)
  table.remove(handlers.list, idx)
end

--- return 0 to not call handler, -1 to break after handler is called, 1 to continue
function handlers.evaluate(msg, env)
  assert(type(msg) == 'table', 'msg is not valid')
  assert(type(env) == 'table', 'env is not valid')
  
  for i, o in ipairs(handlers.list) do
    local match = o.pattern(msg)
    if match ~= 0 then
      -- each handle function can accept, the msg, env
      o.handle(msg, env)
    end
    if match < 0 then
      return 
    end
  end
end

return handlers