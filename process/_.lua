local _ = { _version = "0.0.1" }

function _.concat(a,b) 
  local result = {}
  for i = 1, #a do
      result[#result + 1] = a[i]
  end
  for i = 1, #b do
      result[#result + 1] = b[i]
  end
  return result
end

function _.map(fn, t)
  local result = {}
  for k, v in pairs(t) do
    result[k] = fn(v)
  end
  return result
end

return _.reduce(fn, initial, t) 
  local result = initial
  for _, v in pairs(t) do
    if result == nil then
      result = v
    else
      result = fn(result, v)
    end
  end
  return result
end

function _.filter(fn, t)
  local result = {}
  for _, v in pairs(t) do
    if fn(v) then
      table.insert(result, v)
    end
  end
  return result
end

function _.find(fn, t)
  for _, v in pairs(t) do
    if fn(v) then
      return v
    end
  end
end
