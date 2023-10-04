
local contract = { _version = "0.0.1" }

function contract.handle(state, action, SmartWeave) 
  -- owner only commands
  if (action.caller == state.owner) then
    if (action.input["function"] == "echo") then
      return {
        state = state,
        result = {
          output = action.input.data,
          messages = {}
        }
      }
    end

    if (action.input["function"] == "eval") then
      local func, err = load("return " .. action.input["data"])
      if not func then 
        return {
          result = {
            error = err
          }
        }
      end
      
      local o, e = func()
      
      if not o then
        return {
          result = {
            error = e 
          }
        }
      end

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
