
local contract = { _version = "0.0.1" }

function contract.handle(state, action, SmartWeave) 
  if (action.input["function"] == "handleMessage") then
    action = {
      -- caller = SmartWeave.transaction.tags["Caller"],
      caller = "todo",
      input = action.input.message
    }
  end
  
  if (action.input["function"] == "receiveMsg") then
    table.insert(state.inbox, action.input.body)
    return {
      state = state,
      result = {
        messages = {},
        output = "received message"
      }
    }
  end

  -- owner only commands
  if (action.caller == state.owner) then
    
    if (action.input["function"] == "eval") then
      local env = {}
      local messages = {}
      
      function env.sendMsg(process, msg)
        
        table.insert(messages, {
          target = process,
          message = {
            ["function"] = "receiveMsg",
            body = msg
          }
        })
        return "message queued to send"
      end

      function env.checkMsgs() 
        local msgoutput = ""
        for i,v in ipairs(state.inbox) do
          msgoutput = msgoutput .. ", " .. v
        end
        return msgoutput
      end

      function env.reset() 
        return "reset"
      end

      -- load env
      for i,v in ipairs(state.env.logs) do
        load(v,'memory','t', env)()
      end

      messages = {}
      
      -- run expr
      local func, err = load(action.input["data"], 'aos', 't', env)
      if not func then 
        return {
          result = {
            error = err
          }
        }
      end
      
      local o, e = func()
      
      if e then
        return {
          result = {
            error = e 
          }
        }
      end
      
      if type(o) ~= 'string' then
        o = tostring(o)
      end

      
      local logs = state.env.logs
      
      table.insert(logs, action.input["data"])
      state.env = { logs = logs }
      -- reset logs
      if o == "reset" then
        state.env = { logs = {} }
      end

      return {
        state = state,
        result = {
          output = o,
          messages = messages
        }
      }
    end
  end

  -- do stuff
  local response = {
    result = { error = "could not find action" }
  }
  return response
end

return contract
