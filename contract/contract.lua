
local contract = { _version = "0.0.1" }

function contract.handle(state, action, SmartWeave) 
 
  -- owner only commands
  if (action.caller == state.owner) then
    
    if (action.input["function"] == "eval") then
      local env = {}
      for i,v in ipairs(state.env.logs) do
        load(v,'memory','t', env)()
      end
      
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

      return {
        state = state,
        result = {
          output = o,
          messages = {}
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
