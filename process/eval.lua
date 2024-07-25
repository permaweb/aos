local stringify = require(".stringify")
-- handler for eval
return function (ao)
  return function (msg)
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
      ao.outbox.Error = err
      return
    end
    if e then 
      ao.outbox.Error = e
      return 
    end
    if HANDLER_PRINT_LOGS and output then
      table.insert(HANDLER_PRINT_LOGS, type(output) == "table" and stringify.format(output) or tostring(output))
    else 
      -- set result in outbox.Output (Left for backwards compatibility)
      ao.outbox.Output = {  
        json = type(output) == "table" and pcall(function () return json.encode(output) end) and output or "undefined",
        data = {
          output = type(output) == "table" and stringify.format(output) or output,
          prompt = Prompt()
        }, 
        prompt = Prompt() 
      }

    end
  end 
end
