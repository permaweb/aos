local JSON = require("json")
local pretty = require('.src.pretty')
local base64 = require('.src.base64')

ao = require('.src.ao')
handlers = require('.src.handlers')

local process = { _version = "0.1.0" }

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

function prompt() 
  -- return "inbox: [" .. #inbox .. "] aos"
  return "aos"
end

function initializeState(msg, env) 
  if not owner then
    owner = env.process.owner
  end 

  if not inbox then
    inbox = {}
  end

  if not name then
    local aosName = findObject(msg.tags, "name", "name")
    if aosName then
      name = aosName.value
    else 
      name = 'aos'
    end
  end
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

function process.handle(msg, env) 
  initializeState(msg, env)

  local fn = findObject(msg.tags, "name", "function")
  
  if fn and fn.value == "eval" and owner == msg.owner then
    local messages = {}
    local spawns = {}
    
    function send(target, input) 
      if type(input) == "string" then
        input = { body = input }
      end
      local message = ao.send(input, target, env)
      table.insert(messages, message)     
      return 'message added to outbox'
    end

    function spawn(data, input) 
      local spawn = ao.spawn(data, input, env)
      table.insert(spawns, spawn)
      return 'spawn process request'
    end

    function installManpage(tx) 
      if not tx then 
        return
      end

      local message = ao.send({
        ['ao-load'] = tx, 
        ['function'] = 'install-manpage'}, env.process.id, env
      )
      table.insert(messages, message)
      return 'installing manpage'
    end
    

    function list() 
      return pretty.tprint(inbox)
    end
  
    -- exec expression
    local expr = findObject(msg.tags, "name", "expression")
    
    local func, err = load("return " .. expr.value, 'aos', 't', _G)
    local output = "" 
    if err then
      func, err = load(expr.value, 'aos', 't', _G)
    end
    if func then
      output, e = func()
    else 
      output = err
    end   
    if e then output = e end
    
    return { output = { data = { output = output, prompt = prompt() } }, messages = messages, spawns = spawns }
  end

  if fn and fn.value == "install-manpage" then
    if msg.data and findObject(msg.data.tags, "name", "ao-manpage") then
      page = findObject(msg.data.tags, "name", "ao-manpage").value
      manpages[page] = base64.decode(msg.data.data)
      return { output = { data = "installed manpage" }, messages = {}, spawns = {} }
    end
  end

  if #handlers.list > 0 then
    local res = handlers.evaluate(msg)
    if res.output then
      return res
    end
  end
  -- Add Message to Inbox
  table.insert(inbox, msg)


  local response = {
    result = { error = "could not find action" }
  }
  return response
end

return process