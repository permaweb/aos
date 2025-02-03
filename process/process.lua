--- The Process library provides an environment for managing and executing processes on the AO network. It includes capabilities for handling messages, spawning processes, and customizing the environment with programmable logic and handlers. Returns the process table.
-- @module process

-- @dependencies
local pretty = require('.pretty')
local base64 = require('.base64')
local json = require('json')
local chance = require('.chance')
local crypto = require('.crypto.init')
local coroutine = require('coroutine')
-- set alias ao for .ao library
if not _G.package.loaded['ao'] then _G.package.loaded['ao'] = require('.ao') end

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
ao = nil
if _G.package.loaded['.ao'] then
  ao = require('.ao')
elseif _G.package.loaded['ao'] then
  ao = require('ao')
end
-- Implement assignable polyfills on _ao
assignment.init(ao)

--- The process table
-- @table process
-- @field _version The version number of the process

local process = { _version = "2.0.3" }
-- The maximum number of messages to store in the inbox
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

--- Remove the last three lines from a string
-- @lfunction removeLastThreeLines
-- @tparam {string} input The string to remove the last three lines from
-- @treturn {string} The string with the last three lines removed
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

--- Insert a message into the inbox and manage overflow
-- @lfunction insertInbox
-- @tparam {table} msg The message to insert into the inbox
local function insertInbox(msg)
  table.insert(Inbox, msg)
  if #Inbox > maxInboxCount then
    local overflow = #Inbox - maxInboxCount
    for i = 1,overflow do
      table.remove(Inbox, 1)
    end
  end
end

--- Find an object in an array by a given key and value
-- @lfunction findObject
-- @tparam {table} array The array to search through
-- @tparam {string} key The key to search for
-- @tparam {any} value The value to search for
local function findObject(array, key, value)
  for i, object in ipairs(array) do
    if object[key] == value then
      return object
    end
  end
  return nil
end

--- Convert a message's tags to a table of key-value pairs
-- @function Tab
-- @tparam {table} msg The message containing tags
-- @treturn {table} A table with tag names as keys and their values
function Tab(msg)
  local inputs = {}
  for _, o in ipairs(msg.Tags) do
    if not inputs[o.name] then
      inputs[o.name] = o.value
    end
  end
  return inputs
end

--- Generate a prompt string for the current process
-- @function Prompt
-- @treturn {string} The custom command prompt string
function Prompt()
  return Colors.green .. Name .. Colors.gray
    .. "@" .. Colors.blue .. "aos-" .. process._version .. Colors.gray
    .. "[Inbox:" .. Colors.red .. tostring(#Inbox) .. Colors.gray
    .. "]" .. Colors.reset .. "> "
end

--- Print a value, formatting tables and converting non-string types
-- @function print
-- @tparam {any} a The value to print
function print(a)
  if type(a) == "table" then
    a = stringify.format(a)
  end
  --[[
In order to print non string types we need to convert to string
  ]]
  if type(a) == "boolean" then
    a = Colors.blue .. tostring(a) .. Colors.reset
  end
  if type(a) == "nil" then
    a = Colors.red .. tostring(a) .. Colors.reset
  end
  if type(a) == "number" then
    a = Colors.green .. tostring(a) .. Colors.reset
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

--- Send a message to a target process
-- @function Send
-- @tparam {table} msg The message to send
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

--- Spawn a new process
-- @function Spawn
-- @tparam {...any} args The arguments to pass to the spawn function
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

--- Calls Handlers.receive with the provided pattern criteria, awaiting a message that matches the criteria.
-- @function Receive
-- @tparam {table} match The pattern criteria for the message
-- @treturn {any} The result of the message handling
function Receive(match)
  return Handlers.receive(match)
end

--- Assigns based on the assignment passed.
-- @function Assign
-- @tparam {table} assignment The assignment to be made
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

--- Converts a string to a seed value
-- @lfunction stringToSeed
-- @tparam {string} s The string to convert to a seed
-- @treturn {number} The seed value
-- this is a temporary approach...
local function stringToSeed(s)
  local seed = 0
  for i = 1, #s do
      local char = string.byte(s, i)
      seed = seed + char
  end
  return seed
end

--- Initializes or updates the state of the process based on the incoming message and environment.
-- @lfunction initializeState
-- @tparam {table} msg The message to initialize the state with
-- @tparam {table} env The environment to initialize the state with
local function initializeState(msg, env)
  if not Seeded then
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

  -- Owner should only be assiged once
  if env.Process.Id == msg.Id and not Owner then
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

--- Prints the version of the process
-- @function Version
function Version()
  print("version: " .. process._version)
end

--- Main handler for processing incoming messages. It initializes the state, processes commands, and handles message evaluation and inbox management.
-- @function handle
-- @tparam {table} msg The message to handle
-- @tparam {table} _ The environment to handle the message in
function process.handle(msg, _)
  local env = nil
  if _.Process then
    env = _
  else
    env = _.env
  end
  
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
    if msg.From ~= ao.id then
      Send({Target = msg.From, Data = "Message is not trusted by this process!"})
    end
    print('Message is not trusted! From: ' .. msg.From .. ' - Owner: ' .. msg.Owner)
    return ao.result({ }) 
  end

  if ao.isAssignment(msg) and not ao.isAssignable(msg) then
    if msg.From ~= ao.id then
      Send({Target = msg.From, Data = "Assignment is not trusted by this process!"})
    end
    print('Assignment is not trusted! From: ' .. msg.From .. ' - Owner: ' .. msg.Owner)
    return ao.result({ })
  end

  Handlers.add("_eval",
    function (msg)
      return msg.Action == "Eval" and Owner == msg.From
    end,
    require('.eval')(ao)
  )

  -- Added for aop6 boot loader
  -- See: https://github.com/permaweb/aos/issues/342
  -- Only run bootloader when Process Message is First Message
  if env.Process.Id == msg.Id then
    Handlers.once("_boot",
      function (msg)
        return msg.Tags.Type == "Process" and Owner == msg.From 
      end,
      require('.boot')(ao)
    )
  end

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
      -- clear functions
      newMsg.reply = nil
      newMsg.forward = nil 
      
      ao.send(newMsg)
    end

  local co = coroutine.create(
    function()
      return pcall(Handlers.evaluate, msg, env)
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
      local printData = table.concat(HANDLER_PRINT_LOGS, "\n")
      return { Error = printData .. '\n\n' .. Colors.red .. 'error:\n' .. Colors.reset .. result }
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
    local printData = table.concat(HANDLER_PRINT_LOGS, "\n")
    return ao.result({Error = printData .. '\n\n' .. Colors.red .. 'error:\n' .. Colors.reset .. result, Messages = {}, Spawns = {}, Assignments = {} })
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
  elseif msg.Tags.Type == "Process" and Owner == msg.From then 
    local response = ao.result({ 
      Output = {
        data = table.concat(HANDLER_PRINT_LOGS, "\n"),
        prompt = Prompt(),
        print = true
      }
    })
    HANDLER_PRINT_LOGS = {} -- clear logs
    return response

    -- local response = nil
  
    -- -- detect if there was any output from the boot loader call
    -- for _, value in pairs(HANDLER_PRINT_LOGS) do
    --   if value ~= "" then
    --     -- there was output from the Boot Loader eval so we want to print it
    --     response = ao.result({ Output = { data = table.concat(HANDLER_PRINT_LOGS, "\n"), prompt = Prompt(), print = true } })
    --     break
    --   end
    -- end
  
    -- if response == nil then 
    --   -- there was no output from the Boot Loader eval, so we shouldn't print it
    --   response = ao.result({ Output = { data = "", prompt = Prompt() } })
    -- end

    -- HANDLER_PRINT_LOGS = {} -- clear logs
    -- return response
  else
    local response = ao.result({ Output = { data = table.concat(HANDLER_PRINT_LOGS, "\n"), prompt = Prompt(), print = true } })
    HANDLER_PRINT_LOGS = {} -- clear logs
    return response
  end
end

return process
