local ao = require(".src.ao")

local process = { _version = "0.0.1" }

local function findByProp(array, prop, value)
  for idx, object in ipairs(array) do
    if object[prop] == value then
      return object
    end
  end
  return nil
end

function process.handle(msg, env) 
  local sender = findByProp(msg.tags, "name", "Forwarded-For")  
  local msgObject = findByProp(msg.tags, "name", "msg")
  if not msgObject then
    return {
      error = "cant find msg"
    }
  end
  if not sender then
    return {
      error = "cant find sender"
    }
  end

  local response = {
    output = "echo " .. msgObject.value,
    messages = { ao.send({ msg = msgObject.value }, sender.value, env) },
    spawns = {}
  }
  
  return response
end

return process
