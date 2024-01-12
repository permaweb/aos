local pretty = require('.pretty')
local base64 = require('.base64')

Dump = require('.dump')
Utils = require('.utils')
Handlers = require('.handlers')

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
  -- return "inbox: [" .. #inbox .. "] aos"
  return "aos> "
end

local function initializeState(msg, env) 
  Errors = Errors or {}
  Inbox = Inbox or {}

  if not Owner then
    Owner = env.Process.Owner
  end 

  if not Name then
    local aosName = findObject(msg.Tags, "name", "Name")
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
  msg.TagArray = msg.Tags
  msg.Tags = Tab(msg)
   
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
    
    return ao.result({ Output = { data = { output = output, prompt = Prompt() }}})
  end

  if msg.Tags['function'] ==  "Install-Manpage" then
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
    local status, result = pcall(function () 
      Handlers.evaluate(msg, ao.env)
    end)
    if status then
      if #ao.outbox.Messages > 0 or #ao.outbox.Spawns > 0 then
        local response = ao.result({
          Output = "Cranking"
        })
        
        return response
      end
    else 
      table.insert(Errors, 'An Error occured in your handlers')
      return ao.result({Output = 'An Error occured in your handlers'})
    end
  end
  -- Add Message to Inbox
  table.insert(Inbox, msg)

  return ao.result({ Error = "could not find action" })
end

return process