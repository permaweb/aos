local ao = { _version = "0.0.1", id = "" }

function ao.send(input, target) 
  -- assert(typeof(input) == 'table', 'input should be a table')
  -- assert(typeof(target) == 'string', 'target should be a string')
  -- assert(typeof(AO) == 'table', 'env should be a table')

  local message = {
    target = target,
    tags = {
      { name = "Data-Protocol", value = "ao" },
      { name = "ao-type", value = "message" },
      { name = "Forwarded-For", value = ao.id }
    }
  }
  
  for k,v in pairs(input) do
    table.insert(message.tags, { name = k, value = v })
  end

  return message
end

function ao.spawn(data, tags, AO) 
  assert(data ~= nil, 'data should have a value')
  assert(typeof(tags) == 'table', 'tags should be a table')
  assert(typeof(AO) == 'table', 'env should be a table')

  local spawn = {
    data = data,
    tags = {
      { name = "Data-Protocol", value = "ao" },
      { name = "ao-type", value = "process" },
      { name = "Forwarded-For", value = AO.process.id }
    }
  }

  for k,v in pairs(input) do
    table.insert(spawn.tags, { name = k, value = v })
  end

  return spawn
end

return ao