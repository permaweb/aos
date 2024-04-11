local pretty = require('.pretty')
local base64 = require('.base64')
local json = require('json')
local chance = require('.chance')
local crypto = require('.crypto.init')

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
local _ao = require('ao')
local process = { _version = "0.2.0" }
local maxInboxCount = 10000

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
  return "aos> "
end

function print(a)
  if type(a) == "table" then
    a = stringify.format(a)
  end
  
  pcall(function () 
    local data = a
    if _ao.outbox.Output.data then
      data =  _ao.outbox.Output.data .. "\n" .. a
    end
    _ao.outbox.Output = { data = data, prompt = Prompt(), print = true }
  end)

  return tostring(a)
end

function Send(msg)
  _ao.send(msg)
  return 'message added to outbox'
end

function Spawn(module, msg)
  if not msg then
    msg = {}
  end

  _ao.spawn(module, msg)
  return 'spawn process request'
end

function Assign(assignment)
  _ao.assign(assignment)
  return 'assignment added to outbox'
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

function process.handle(msg, ao)
  ao.id = ao.env.Process.Id
  initializeState(msg, ao.env)
  -- tagify msg
  msg.TagArray = msg.Tags
  msg.Tags = Tab(msg)
  -- tagify Process
  ao.env.Process.TagArray = ao.env.Process.Tags
  ao.env.Process.Tags = Tab(ao.env.Process)
  -- init Errors
  Errors = Errors or {}
  -- clear Outbox
  ao.clearOutbox()

  Handlers.add("_eval", 
    function (msg)
      return msg.Action == "Eval" and Owner == msg.From
    end,
    require('.eval')(ao)
  )
  Handlers.append("_default", function () return true end, require('.default')(insertInbox))
  -- call evaluate from handlers passing env
  
  local status, result = pcall(Handlers.evaluate, msg, ao.env)
  

  if not status then
    table.insert(Errors, result)
    return { Error = result }
    -- return {
    --   Output = { 
    --     data = { 
    --       prompt = Prompt(), 
    --       json = 'undefined', 
    --       output = result 
    --     }
    --   }, 
    --   Messages = {}, 
    --   Spawns = {}
    -- }
  end
  
  return ao.result({ })
end

return process
