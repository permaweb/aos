local Test = {}
Test.__index = Test

function Test.new(name)
  local self = setmetatable({}, Test)
  self.name = name
  self.tests = {}
  return self
end

function Test:add(name, func)
  table.insert(self.tests, { name = name, func = func })
end

-- propEq 
local propEq = function (prop, value) 
  return function (tbl)
    return tbl[prop] == value
  end
end

-- findIndex
local findIndex = function (func, tbl)
  for i, v in ipairs(tbl) do 
    if func(tbl[i]) then
      return i
    end
  end
end

function Test:remove(name)
  local idx = findIndex(propEq('name', name), self.tests)
  table.remove(self.tests, idx)  
end

function Test:run()
    local output = ""
    local out = function (txt) 
      output = output .. txt .. '\n'
    end
    out("Running tests for " .. self.name)
    local passed = 0
    local failed = 0
    for _, test in ipairs(self.tests) do
        local status, err = pcall(test.func)
        if status then
            out(Colors.green .. "✔ " .. Colors.reset .. test.name)
            passed = passed + 1
        else
            out(Colors.red .. "✘ " .. Colors.reset .. test.name .. ": " .. err)
            failed = failed + 1
        end
    end
    out(string.format(Colors.blue .. "Passed: %d, Failed: %d" .. Colors.reset, passed, failed))
    return output
end

return Test
