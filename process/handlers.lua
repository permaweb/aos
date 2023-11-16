local handlers = { _version = "0.0.1" }

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
  local idx = findIndexByProp(handlers.list, "name", name)
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

--- return 0 to not call handler, -1 to break after handler is called, 1 to continue
function handlers.evaluate(msg, response)
  assert(type(msg) == 'table', 'msg is not valid')
  if not response then
    response = {}
  end

  for i, o in ipairs(handlers.list) do
    local match = o.pattern(msg)
    if match ~= 0 then
      response = o.handle(msg, response)
    end
    if match < 0 then
      return response
    end
  end
  return response
end

return handlers