local contract = { _version = "0.0.1" }

function contract.handle(state, message, AO) 

  if message.tags["function"] == "eval" and state.owner == message.owner then
    local env = {
      _global = _G,
      state = state
    }
    -- load fns into env
    -- exec expression
    local func, err = load(message.tags.expression, 'aos', 't', env)
    local output = "" 
    if func then
      output, e = func()
    else 
      output = err
    end 
    if e then output = e end

    return { state = state, result = { output = output, messages = {}, spawns = {} }}
  end

  table.insert(state.inbox, message.tags.expression)

  if message.tags['function'] and state._fns[message.tags['function']] then
    load(string.format("%s = %s", message.tags['function'], state._fns[message.tags['function']]), 'fns', 't', env)()
    load(string.format("%s()", message.tags['function']), "fns", 't', env)()

  end



  local response = {
    result = { error = "could not find action" }
  }
  return response
end

return contract