local pretty = require('.pretty')
local base64 = require('.base64')
local json = require('json')
local chance = require('.chance')
local crypto = require('.crypto.init')
local coroutine = require('coroutine')

Colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

Bell = "\x07"

Dump = require('.dump')
Utils = require('.utils')
Handlers = require('.handlers')
local stringify = require(".stringify")
local assignment = require('.assignment')
ao = require('.ao')

-- Implement assignable polyfills on _ao
assignment.init(ao)

local process = { _version = "2.0.0.rc1" }
local maxInboxCount = 10000

-- wrap ao.send and ao.spawn for magic table
local aosend = ao.send 
local aospawn = ao.spawn
ao.send = function (msg)
  if msg.Data and type(msg.Data) == 'table' then
    msg['Content-Type'] = 'application/json'
    msg.Data = require('json').encode(msg.Data)
  end
  return aosend(msg)
end
ao.spawn = function (module, msg) 
  if msg.Data and type(msg.Data) == 'table' then
    msg['Content-Type'] = 'application/json'
    msg.Data = require('json').encode(msg.Data)
  end
  return aospawn(module, msg)
end

local function removeLastThreeLines(input)
  local lines = {}
  for line in input:gmatch("([^\n]*)\n?") do
      table.insert(lines, line)
  end

  -- Remove the last three lines
  for i = 1, 3 do
      table.remove(lines)
  end

  -- Concatenate the remaining lines
  return table.concat(lines, "\n")
end


local function insertInbox(msg)
  table.insert(Inbox, msg)
  if #Inbox > maxInboxCount then
    local overflow = #Inbox - maxInboxCount 
    for i = 1,overflow do
      table.remove(Inbox, 1)
    end
  end 
end

local function findObject(array, key, value)
  for i, object in ipairs(array) do
    if object[key] == value then
      return object
    end
  end
  return nil
end

function Tab(msg)
  local inputs = {}
  for _, o in ipairs(msg.Tags) do
    if not inputs[o.name] then
      inputs[o.name] = o.value
    end
  end
  return inputs
end

function Prompt()
  return Colors.green .. Name .. Colors.gray
    .. "@" .. Colors.blue .. "aos-" .. process._version .. Colors.gray
    .. "[Inbox:" .. Colors.red .. tostring(#Inbox) .. Colors.gray
    .. "]" .. Colors.reset .. "> "
end

function print(a)
  if type(a) == "table" then
    a = stringify.format(a)
  end
  
  local data = a
  if ao.outbox.Output.data then
    data =  ao.outbox.Output.data .. "\n" .. a
  end
  ao.outbox.Output = { data = data, prompt = Prompt(), print = true }

  -- Only supported for newer version of AOS
  if HANDLER_PRINT_LOGS then 
    table.insert(HANDLER_PRINT_LOGS, a)
    return nil
  end

  return tostring(a)
end

function Send(msg)
  if not msg.Target then
    print("WARN: No target specified for message. Data will be stored, but no process will receive it.")
  end
  local result = ao.send(msg)
  return {
    output = "Message added to outbox",
    receive = result.receive,
    onReply = result.onReply
  }
end

function Spawn(...)
  local module, spawnMsg

  if select("#", ...) == 1 then
    spawnMsg = select(1, ...)
    module = ao._module
  else
    module = select(1, ...)
    spawnMsg = select(2, ...)
  end

  if not spawnMsg then
    spawnMsg = {}
  end
  local result = ao.spawn(module, spawnMsg)
  return {
    output = "Spawn process request added to outbox",
    after = result.after,
    receive = result.receive
  }  
end

function Receive(match)
  return Handlers.receive(match)
end

function Assign(assignment)
  if not ao.assign then
    print("Assign is not implemented.")
    return "Assign is not implemented."
  end
  ao.assign(assignment)
  print("Assignment added to outbox.")
  return 'Assignment added to outbox.'
end

Seeded = Seeded or false

-- this is a temporary approach...
local function stringToSeed(s)
  local seed = 0
  for i = 1, #s do
      local char = string.byte(s, i)
      seed = seed + char
  end
  return seed
end

local function initializeState(msg, env)
  if not Seeded then
    --math.randomseed(1234)
    chance.seed(tonumber(msg['Block-Height'] .. stringToSeed(msg.Owner .. msg.Module .. msg.Id)))
    math.random = function (...)
      local args = {...}
      local n = #args
      if n == 0 then
        return chance.random()
      end
      if n == 1 then
        return chance.integer(1, args[1])
      end
      if n == 2 then
        return chance.integer(args[1], args[2])
      end
      return chance.random()
    end
    Seeded = true
  end
  Errors = Errors or {}
  Inbox = Inbox or {}

  -- temporary fix for Spawn
  if not Owner then
    local _from = findObject(env.Process.Tags, "name", "From-Process")
    if _from then
      Owner = _from.value
    else
      Owner = msg.From
    end
  end

  if not Name then
    local aosName = findObject(env.Process.Tags, "name", "Name")
    if aosName then
      Name = aosName.value
    else
      Name = 'aos'
    end
  end

end

function Version()
  print("version: " .. process._version)
end

function process.handle(msg, env)
  ao.init(env)
  -- relocate custom tags to root message
  msg = ao.normalize(msg)
  -- set process id
  ao.id = ao.env.Process.Id
  initializeState(msg, ao.env)
  HANDLER_PRINT_LOGS = {}
  
  -- set os.time to return msg.Timestamp
  os.time = function () return msg.Timestamp end

  -- tagify msg
  msg.TagArray = msg.Tags
  msg.Tags = Tab(msg)
  -- tagify Process
  ao.env.Process.TagArray = ao.env.Process.Tags
  ao.env.Process.Tags = Tab(ao.env.Process)
  -- magic table - if Content-Type == application/json - decode msg.Data to a Table
  if msg.Tags['Content-Type'] and msg.Tags['Content-Type'] == 'application/json' then
    msg.Data = require('json').decode(msg.Data or "{}")
  end
  -- init Errors
  Errors = Errors or {}
  -- clear Outbox
  ao.clearOutbox()

  -- Only trust messages from a signed owner or an Authority
  if msg.From ~= msg.Owner and not ao.isTrusted(msg) then
    Send({Target = msg.From, Data = "Message is not trusted by this process!"})
    print('Message is not trusted! From: ' .. msg.From .. ' - Owner: ' .. msg.Owner)
    return ao.result({ }) 
  end

  if ao.isAssignment(msg) and not ao.isAssignable(msg) then
    Send({Target = msg.From, Data = "Assignment is not trusted by this process!"})
    print('Assignment is not trusted! From: ' .. msg.From .. ' - Owner: ' .. msg.Owner)
    return ao.result({ })
  end

  Handlers.add("_eval",
    function (msg)
      return msg.Action == "Eval" and Owner == msg.From
    end,
    require('.eval')(ao)
  )
  Handlers.append("_default", function () return true end, require('.default')(insertInbox))
  -- call evaluate from handlers passing env
  msg.reply =
    function(replyMsg)
      replyMsg.Target = msg["Reply-To"] or (replyMsg.Target or msg.From)
      replyMsg["X-Reference"] = msg["X-Reference"] or msg.Reference
      replyMsg["X-Origin"] = msg["X-Origin"] or nil

      return ao.send(replyMsg)
    end
  
  msg.forward =
    function(target, forwardMsg)
      -- Clone the message and add forwardMsg tags
      local newMsg =  ao.sanitize(msg)
      forwardMsg = forwardMsg or {}

      for k,v in pairs(forwardMsg) do
        newMsg[k] = v
      end

      -- Set forward-specific tags
      newMsg.Target = target
      newMsg["Reply-To"] = msg["Reply-To"] or msg.From
      newMsg["X-Reference"] = msg["X-Reference"] or msg.Reference
      newMsg["X-Origin"] = msg["X-Origin"] or msg.From

      ao.send(newMsg)
    end

  local co = coroutine.create(
    function()
      return pcall(Handlers.evaluate, msg, ao.env)
    end
  )
  local _, status, result = coroutine.resume(co)

  -- Make sure we have a reference to the coroutine if it will wake up.
  -- Simultaneously, prune any dead coroutines so that they can be
  -- freed by the garbage collector.
  table.insert(Handlers.coroutines, co)
  for i, x in ipairs(Handlers.coroutines) do
    if coroutine.status(x) == "dead" then
      table.remove(Handlers.coroutines, i)
    end
  end

  if not status then
    if (msg.Action == "Eval") then
      table.insert(Errors, result)
      return { Error = result }
    end 
    --table.insert(Errors, result)
    --ao.outbox.Output.data = ""
    if msg.Action then
      print(Colors.red .. "Error" .. Colors.gray .. " handling message with Action = " .. msg.Action  .. Colors.reset)
    else
      print(Colors.red .. "Error" .. Colors.gray .. " handling message " .. Colors.reset)
    end
    print(Colors.green .. result .. Colors.reset)
    print("\n" .. Colors.gray .. removeLastThreeLines(debug.traceback()) .. Colors.reset)
    return ao.result({ Messages = {}, Spawns = {}, Assignments = {} })
  end

  if msg.Action == "Eval" then
    local response = ao.result({ 
      Output = {
        data = table.concat(HANDLER_PRINT_LOGS, "\n"),
        prompt = Prompt(),
        test = Dump(HANDLER_PRINT_LOGS)
      }
    })
    HANDLER_PRINT_LOGS = {} -- clear logs
    return response
  else
    local response = ao.result({ Output = { data = table.concat(HANDLER_PRINT_LOGS, "\n"), prompt = Prompt(), print = true } })
    HANDLER_PRINT_LOGS = {} -- clear logs
    return response
  end
end

return process
