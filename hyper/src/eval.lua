--- The Eval module provides a handler for evaluating Lua expressions. Returns the eval function.
-- @module eval

local stringify = require(".stringify")
local json = require('.json')
--- The eval function.
-- Handler for executing and evaluating Lua expressions.
-- After execution, the result is stringified and placed in ao.outbox.Output.
-- @function eval
-- @tparam {table} ao The ao environment object
-- @treturn {function} The handler function, which takes a message as an argument.
-- @see stringify
return function (ao)
  return function (msg)
    -- exec expression
    local expr = msg.body.data
    local func, err = load("return " .. expr, 'aos', 't', _G)
    local output = ""
    local e = nil
    if err then
      func, err = load(expr, 'aos', 't', _G)
    end
    if func then
      output, e = func()
    else
      ao.outbox.Error = err
      return
    end
    if e then
      ao.outbox.Error = e
      return
    end
    if HandlerPrintLogs and output then
      table.insert(HandlerPrintLogs,
        type(output) == "table"
        and stringify.format(output)
        or tostring(output)
      )
      -- print(stringify.format(HandlerPrintLogs))
    else
      -- set result in outbox.Output (Left for backwards compatibility)
      ao.outbox.Output = {
        data = type(output) == "table" 
          and stringify.format(output) or tostring(output),
        prompt = Prompt()
      }

    end
  end
end
