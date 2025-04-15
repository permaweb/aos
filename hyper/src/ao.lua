Handlers = Handlers or require('.handlers')

local oldao = ao or {}

local utils = require('.utils')

local ao = {
    _version = "0.0.6",
    id = oldao.id or "",
    _module = oldao._module or "",
    authorities = oldao.authorities or {},
    reference = oldao.reference or 0,
    outbox = oldao.outbox or
        {Output = {}, Messages = {}, Spawns = {}, Assignments = {}},
    nonExtractableTags = {
        'Data-Protocol', 'Variant', 'From-Process', 'From-Module', 'Type',
        'From', 'Owner', 'Anchor', 'Target', 'Data', 'Tags', 'Read-Only'
    },
    nonForwardableTags = {
        'Data-Protocol', 'Variant', 'From-Process', 'From-Module', 'Type',
        'From', 'Owner', 'Anchor', 'Target', 'Tags', 'TagArray', 'Hash-Chain',
        'Timestamp', 'Nonce', 'Epoch', 'Signature', 'Forwarded-By',
        'Pushed-For', 'Read-Only', 'Cron', 'Block-Height', 'Reference', 'Id',
        'Reply-To'
    },
    Nonce = nil
}

function ao.clearOutbox()
  ao.outbox = { Output = {}, Messages = {}, Spawns = {}, Assignments = {}}
end

local function getId(m)
  local id = ""
  utils.map(function (k)
    local c = m.commitments[k]
    if c.alg == "rsa-pss-sha512" then
      id = k
    elseif c.alg == "signed" and c['commitment-device'] == "ans104" then
      id = k
    end
  end, utils.keys(m.commitments)
  )
  return id
end

function ao.init(env)
  if ao.id == "" then ao.id = getId(env.process) end

    -- if ao._module == "" then
    --   ao._module = env.Module.Id
    -- end
    -- TODO: need to deal with assignables
    -- if #ao.authorities < 1 then
    --     for _, o in ipairs(env.Process.Tags) do
    --         if o.name == "Authority" then
    --             table.insert(ao.authorities, o.value)
    --         end
    --     end
    -- end

    ao.outbox = {Output = {}, Messages = {}, Spawns = {}, Assignments = {}}
    ao.env = env

end

function ao.send(msg)
  assert(type(msg) == 'table', 'msg should be a table')

  ao.reference = ao.reference + 1
  local referenceString = tostring(ao.reference)
  -- set kv
  msg.Reference = referenceString

  -- clone message info and add to outbox
  table.insert(ao.outbox.Messages, utils.reduce(
    function (acc, key)
      acc[key] = msg[key]
      return acc
    end,
    {},
    utils.keys(msg)
  ))

  if msg.Target then
    msg.onReply = function(...)
      local from, resolver
      if select("#", ...) == 2 then
        from = select(1, ...)
        resolver = select(2, ...)
      else
        from = msg.Target
        resolver = select(1, ...)
      end
      Handlers.once({
        From = from,
        ["X-Reference"] = referenceString
      }, resolver)
    end
  end
  return msg
end

function ao.spawn(module, msg)
  assert(type(module) == "string", "Module source id is required!")
  assert(type(msg) == "table", "Message must be a table.")

  ao.reference = ao.reference + 1

  local spawnRef = tostring(ao.reference)

  
  msg["Reference"] = spawnRef


  -- clone message info and add to outbox
  table.insert(ao.outbox.Spawns, utils.reduce(
    function (acc, key)
      acc[key] = msg[key]
      return acc
    end,
    {},
    utils.keys(msg)
  ))

  msg.onReply = function(cb)
    Handlers.once({
      Action = "Spawned",
      From = ao.id,
      ["X-Reference"] = spawnRef
    }, cb)
  end

  return msg

end

function ao.result(result)
  if ao.outbox.Error or result.Error then
    return { Error = result.Error or ao.outbox.Error }
  end
  return {
    Output = result.Output or ao.output.Output,
    Messages = ao.outbox.Messages,
    Spawns = ao.outbox.Spawns,
    Assignments = ao.outbox.Assignments
  }
end

-- set global Send and Spawn
Send = Send or ao.send
Spawn = Spawn or ao.spawn

return ao
