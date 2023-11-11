local JSON = require("json")
local ao = require('.src.ao')

local process = { _version = "0.1.0" }

local function findObject(array, key, value)
  for i, object in ipairs(array) do
    if object[key] == value then
      return object
    end
  end
  return nil
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

  if not prompt then
    local promptObject = findObject(msg.tags, "name", "prompt")
    if promptObject then
      prompt = promptObject.value
    else
      prompt = 'aos'
    end
  end
end

function version() 
  print("version: " .. process._version)
end

function man(page) 
  if not page then
    return [[
# aos man page

Welcome to aos, this is your personal process on the aos network. 

What can you do with aos?

* send and receive messages from other processes
* create/spawn new processes
* write programmable logic to customize your aos environment
* add handlers to your process that can be invoked when your process recieves messages

Check out the getting started page to learn more.

```lua
man("getting_started")
```

(scroll up to see full page.)
    ]]
  end
end

function process.handle(msg, env) 
  initializeState(msg, env)

  local fn = findObject(msg.tags, "name", "function")
  
  if fn and fn.value == "eval" and owner == msg.owner then
    local messages = {}
    local spawns = {}
    
    function send(target, input) 
      local message = ao.send(input, target, env)
      table.insert(messages, message)     
      return 'message added to outbox'
    end

    function spawn(data, input) 
      local spawn = ao.spawn(data, input, env)
      table.insert(spawns, spawn)
      return 'spawn process request'
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
    
    return { output = { data = { output = output, prompt = prompt } }, messages = messages, spawns = spawns }
  end
  
  -- Add Message to Inbox
  table.insert(inbox, msg)


  local response = {
    result = { error = "could not find action" }
  }
  return response
end

return process