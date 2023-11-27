ao = require('.src.ao')
handlers = require('.src.handlers')

local process = { _version = "0.0.1" }

function getTagValue(array, prop, value) 
  assert(type(array) == "table", "first argument MUST be table")
  assert(type(prop) == "string", "second argument MUST be string")
  assert(value ~= nil, "third argument MUST NOT be nil")

  for i, o in ipairs(array) do
    if o[prop] == value then
      return o.value
    end
  end
  return nil
end

-- initial state
balances = {}
name = "potato"

function process.handle(msg, env) 
  -- if spawn 
  if getTagValue(msg.tags, "name", "ao-type") == "spawn" then
    handlers.append(balances.pattern, balances.handle, 'balances')
    handlers.append(transfer.pattern, transfer.handle, 'transfer')
    handlers.append(register.pattern, register.handle, 'register')
  end

  return handlers.evaluate(msg, env)
end

return process
