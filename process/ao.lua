local ao = { _version = "0.0.2", id = "" }

function ao.send(input, target) 
  assert(type(input) == 'table', 'input should be a table')
  assert(type(target) == 'string', 'target should be a string')
  
  local me = ao.id
  
  local message = {
    target = target,
    tags = {
      { name = "Data-Protocol", value = "ao" },
      { name = "ao-type", value = "message" },
      { name = "Forwarded-For", value = me }
    }
  }
  
  for k,v in pairs(input) do
    table.insert(message.tags, { name = k, value = v })
  end

  return message
end

function ao.spawn(data, tags) 
  assert(data ~= nil, 'data should have a value')
  assert(type(tags) == 'table', 'tags should be a table')
  
  local me = ao.id

  local spawn = {
    data = data,
    tags = {
      { name = "Data-Protocol", value = "ao" },
      { name = "ao-type", value = "process" },
      { name = "Forwarded-For", value = me }
    }
  }

  for k,v in pairs(input) do
    table.insert(spawn.tags, { name = k, value = v })
  end

  return spawn
end

return ao