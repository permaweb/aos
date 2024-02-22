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
      output = err
    end
    if e then output = e end
    -- set result in outbox.Output 
    ao.outbox.Output = { data = { 
      json = type(output) == "table" and pcall(function () return json.encode(output) end) and output or "undefined",
      output = type(output) == "table" and stringify.format(output) or output, 
      prompt = Prompt() 
    }}
  end 
end
