local ao = { _version = "0.0.3", id = "", outbox = { messages = {}, spawns = {} } }

-- clears outbox
function ao.clearOutbox()
  ao.outbox = { messages = {}, spawns = {} }
end

-- raw send - input is in name,value objects as an array
function ao.sendraw(input, target)
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
    table.insert(message.tags, v)
  end
  -- add message to outbox
  table.insert(ao.outbox.messages, message)
  return message
end


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
  -- add message to outbox
  table.insert(ao.outbox.messages, message)
  return message
end

function ao.spawn(module, tags, data)
  assert(type(module) == "string", "module source id is required!") 
  assert(type(tags) == 'table', 'tags should be a table')
  
  if not data then
    data = "NODATA"
  end

  local me = ao.id

  local spawn = {
    data = data,
    tags = {
      { name = "Data-Protocol", value = "ao" },
      { name = "ao-type", value = "process" },
      { name = "Forwarded-For", value = me },
      { name = "Contract-Src", value = module }
    }
  }

  for k,v in pairs(tags) do
    table.insert(spawn.tags, { name = k, value = v })
  end

   -- add spawn to outbox
   table.insert(ao.outbox.spawns, spawn)

  return spawn
end

-- spawn process with tags as name,value objects in an array
function ao.spawnraw(module, tags, data)
  assert(type(module) == "string", "module source id is required!") 
  assert(type(tags) == 'table', 'tags should be a table')
  
  if not data then
    data = "NODATA"
  end

  local me = ao.id

  local spawn = {
    data = data,
    tags = {
      { name = "Data-Protocol", value = "ao" },
      { name = "ao-type", value = "process" },
      { name = "Forwarded-For", value = me },
      { name = "Contract-Src", value = module }
    }
  }

  for k,v in pairs(tags) do
    table.insert(spawn.tags, v)
  end

   -- add spawn to outbox
   table.insert(ao.outbox.spawns, spawn)

  return spawn
end

return ao