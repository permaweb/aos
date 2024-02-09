local pretty = require('.pretty')
local base64 = require('.base64')
local json = require('json')
local chance = require('.chance')

local colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

Dump = require('.dump')
Utils = require('.utils')
Handlers = require('.handlers')
local stringify = require(".stringify")
local _ao = require('ao')
local process = { _version = "0.2.0" }

Manpages = {
  default = [[
    # aos man page

    Welcome to aos, this is your personal computer on the ao network.

    Check out the Developer Cookbook - https://cookbook_ao.g8way.io

    Installing manpages

    ```lua
    InstallManpage("Xn2AX1W7synUTw7kSDqDAQPL7kVP7xu8g5WizkwiAYo")
    ```

    Once installed then you can print them:

    ```lua
    man("tutorial")
    ```
  ]]
}

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

Seeded = Seeded or false

-- this is a temporary approach...
function stringToSeed(s)
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

  if not Owner then
    Owner = env.Process.Owner
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

function Man(page)
  if not page then
    return Manpages.default
  else
    return Manpages[page]
  end
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

  if msg.Tags['Action'] == "Eval" and Owner == msg.Owner then
    function Send(msg)
      ao.send(msg)
      return 'message added to outbox'
    end

    function Spawn(module, msg)
      if not msg then
        msg = {}
      end

      ao.spawn(module, msg)
      return 'spawn process request'
    end

    function InstallManpage(tx)
      if not tx then
        return
      end

      ao.send({
        Target = ao.id,
        Tags = {
          Load = tx,
          Action = 'Install-Manpage'
        }
      })
      return 'installing manpage'
    end

    -- exec expression
    local expr = msg.Data

    local func, err = load("return " .. expr, 'aos', 't', _G)

    local output = ""
    local e = nil

    if err then
      func, err = load(expr, 'aos', 't', _G)
    end
    if func then
      output, e = func()
    else
      output = err
    end
    if e then output = e end
    
    return ao.result({ Output = { data = { 
      json = type(output) == "table" and pcall(function () return json.encode(output) end) and output or "undefined",
      output = type(output) == "table" and stringify.format(output) or output, 
      prompt = Prompt() 
    } } })
  end

  if msg.Tags['function'] == "Install-Manpage" then
    if msg.Data and msg.Tags['ao-manpage'] then
      local page = msg.Tags['ao-manpage']
      Manpages[page] = base64.decode(msg.Data.Data)
      return ao.result({ Output = { data = "installed manpage" } })
    end
  end

  if #Handlers.list > 0 then
    if #ao.outbox.Messages > 0 or #ao.outbox.Spawns > 0 then
      ao.clearOutbox()
    end
    -- call evaluate from handlers passing env
    Errors = {}
    local status, result = pcall(Handlers.evaluate, msg, ao.env)
     
    if status then
      if not _ao.outbox.Output.data then
        if #ao.outbox.Messages == 0 and #ao.outbox.Spawns == 0 then
          table.insert(Inbox, msg)
            -- New Message from green(key) gray(:) gray(Action) = blue(Help)
          local txt = colors.gray .. "New Message From " .. colors.green .. 
          (msg.From and (msg.From:sub(1,3) .. "..." .. msg.From:sub(-3)) or "unknown") .. colors.gray .. ": "
          if msg.Action then
            txt = txt .. colors.gray .. (msg.Action and ("Action = " .. colors.blue .. msg.Action:sub(1,20)) or "") .. colors.reset
          else
            txt = txt .. colors.gray .. "Data = " .. colors.blue .. (msg.Data and msg.Data:sub(1,20) or "") .. colors.reset
          end
          -- Print to Output
          print(txt)
          
          
        end
      end
      --if #ao.outbox.Messages > 0 or #ao.outbox.Spawns > 0 then
      -- if result then
      local response = ao.result({})
      return response
      --end
    else
      table.insert(Errors, result)
      return ao.result({ })
    end
  end

  -- Add Message to Inbox
  table.insert(Inbox, msg)

  -- New Message from green(key) gray(:) gray(Action) = blue(Help)
  local txt = colors.gray .. "New Message From " .. colors.green .. 
  (msg.From and (msg.From:sub(1,3) .. "..." .. msg.From:sub(-3)) or "unknown") .. colors.gray .. ": "
  if msg.Action then
    txt = txt .. colors.gray .. (msg.Action and ("Action = " .. colors.blue .. msg.Action:sub(1,20)) or "") .. colors.reset
  else
    txt = txt .. colors.gray .. "Data = " .. colors.blue .. (msg.Data and msg.Data:sub(1,20) or "") .. colors.reset
  end
  -- Print to Output
  print(txt)

  return ao.result({ })
end

return process
