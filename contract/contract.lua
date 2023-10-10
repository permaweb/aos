
local JSON = require("json")
local contract = { _version = "0.0.1" }

-- TODO: break contract is several modules
function contract.handle(state, action, SmartWeave) 
  if (action.input["function"] == "handleMessage") then
    action = {
      -- caller = SmartWeave.transaction.tags["Caller"],
      caller = "todo",
      input = action.input.message
    }
  end
  
  if (action.input["function"] == "receiveMsg") then
    table.insert(state.inbox, { from = action.input.from, body = action.input.body })
    if state.receiveFn then
      local fn, err = load(state.receiveFn, 'receivefn', 't', {_global = _G, state = state, SmartWeave = SmartWeave }) 
      local msg = fn()
      return {
        state = state,
        result = {
          messages = {msg},
          output = "processed message"
        }
      }
    end

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
      local env = { inbox = state.inbox, _global = _G }
      local messages = {}
      
      function env.sendMsg(process, msg)
        
        table.insert(messages, {
          target = process,
          message = {
            ["function"] = "receiveMsg",
            body = msg,
            from = SmartWeave.contract.id
          }
        })
        return "message queued to send"
      end

      function env.checkMsgs() 
        -- local msgoutput = ""
        -- for i,v in ipairs(state.inbox) do
        --   msgoutput = msgoutput .. ", " .. v
        -- end
        -- return msgoutput
        return JSON.encode(state.inbox)
      end

      function env.reset() 
        return "reset"
      end

      function env.setReceiveFn(code)
        state.receiveFn = code
        return "set receive function"
      end

      -- load env
      for i,v in ipairs(state.env.logs) do
        local fn, err = load(v,'memory','t', env)
        if fn then
          fn()
        end
      end

      messages = {}
      
      -- run expr
      local func, err = load(action.input["data"], 'aos', 't', env)
      if not func then 
        return {
          state = state,
          result = {
            output = err,
            messages = {}
          }
        }
      end
      
      local o, e = func()
      
      if e then
        o = e
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
