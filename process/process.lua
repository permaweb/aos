local JSON = require("json")
local pretty = require('.pretty')
local base64 = require('.base64')

utils = require('.utils')
handlers = require('.handlers')

local process = { _version = "0.1.3" }

manpages = {
  default = [[
    # aos man page
    
    Welcome to aos, this is your personal computer on the ao network. 
    
    What can you do with aos?
    
    * send and receive messages from other processes
    * create/spawn new processes
    * write programmable logic to customize your aos environment
    * add handlers to your process that can be invoked when your process recieves messages
    
    Installing manpages

    ```lua
    installManpage("Xn2AX1W7synUTw7kSDqDAQPL7kVP7xu8g5WizkwiAYo")
    ```

    Once installed then you can print them:
    
    ```lua
    man("tutorial")
    ```
    
    (scroll up to see full page.)
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

function tab(msg)
  local inputs = {}
  for _, o in ipairs(msg.Tags) do
    if not inputs[o.name] then
      inputs[o.name] = o.value
    end
  end
  return inputs
end

function prompt() 
  -- return "inbox: [" .. #inbox .. "] aos"
  return "aos"
end

function initializeState(msg, env) 
  if not owner then
    owner = env.Process.Owner
  end 

  if not inbox then
    inbox = {}
  end

  if not name then
    local aosName = findObject(msg.Tags, "name", "Name")
    if aosName then
      name = aosName.value
    else 
      name = 'aos'
    end
  end

  ao.id = env.Process.Id
end

function version() 
  print("version: " .. process._version)
end

function man(page) 
  if not page then
    return manpages.default
  else
    return manpages[page]
  end
end

function process.handle(msg, ao) 
  initializeState(msg, ao.env)
  msg.TagArray = msg.Tags
  msg.Tags = tab(msg)
   
  if msg.Tags['function'] == "eval" and owner == msg.Owner then
    
    function send(msg) 
      local message = ao.send(msg)
      return 'message added to outbox'
    end

    function spawn(module, msg) 
      if not msg then
        msg = {}
      end
      
      local spawn = ao.spawn(module, msg)
      return 'spawn process request'
    end

    function installManpage(tx) 
      if not tx then 
        return
      end

      local message = ao.send({
        Target = ao.id,
        Tags = {
          Load = tx,
          ['function'] = 'install-manpage'
        }
      })
      return 'installing manpage'
    end
    

    function list() 
      return pretty.tprint(inbox)
    end
  
    -- exec expression
    local expr = msg.Tags.expression
    
    local func, err = load("return " .. expr, 'aos', 't', _G)
    local output = "" 
    if err then
      func, err = load(expr, 'aos', 't', _G)
    end
    if func then
      output, e = func()
    else 
      output = err
    end   
    if e then output = e end
    
    return ao.result({ Output = { data = { output = output, prompt = prompt() }}})
  end

  if msg.Tags['function'] ==  "install-manpage" then
    if msg.Data and msg.Tags['ao-manpage'] then
      page = msg.Tags['ao-manpage']
      manpages[page] = base64.decode(msg.Data.Data)
      return ao.result({ Output = { data = "installed manpage" } })
    end
  end

  if #handlers.list > 0 then
    if #ao.outbox.Messages > 0 or #ao.outbox.Spawns > 0 then
      ao.clearOutbox()
    end
    -- call evaluate from handlers passing env
    handlers.evaluate(msg, ao.env)
    if #ao.outbox.Messages > 0 or #ao.outbox.Spawns > 0 then
      local response = ao.result({
        Output = "cranking"
      })
      
      return response
    end
  end
  -- Add Message to Inbox
  table.insert(inbox, msg)

  return ao.result({ Error = "could not find action" })
end

return process