local utils = { _version = "0.0.1" }

utils.concat = function (a)
  return function (b) 
    assert(type(a) == "table", "first argument should be a table that is an array")
    assert(type(b) == "table", "second argument should be a table that is an array")
    local result = {}
    for i = 1, #a do
        result[#result + 1] = a[i]
    end
    for i = 1, #b do
        result[#result + 1] = b[i]
    end
    return result
  end
end

utils.map = function (fn)
  return function (t)
    assert(type(fn) == "function", "first argument should be a unary function")
    assert(type(t) == "table", "second argument should be a table that is an array")
    local result = {}
    for k, v in pairs(t) do
      result[k] = fn(v)
    end
    return result
  end
end

utils.reduce = function (fn)
  return function (initial)
    return function (t) 
      assert(type(fn) == "function", "first argument should be a unary function")
      assert(type(t) == "table", "second argument should be a table that is an array")
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
  end
end

utils.filter = function (fn)
  return function (t)
    assert(type(fn) == "function", "first argument should be a unary function")
    assert(type(t) == "table", "second argument should be a table that is an array")
    local result = {}
    for _, v in pairs(t) do
      if fn(v) then
        table.insert(result, v)
      end
    end
    return result
  end
end

utils.find = function (fn)
  return function (t)
    assert(type(fn) == "function", "first argument should be a unary function")
    assert(type(t) == "table", "second argument should be a table that is an array")
    for _, v in pairs(t) do
      if fn(v) then
        return v
      end
    end
  end
end

utils.propEq = function (propName)
  return function (value)
    return function (object)
      assert(type(propName) == "string", "first argument should be a string")
      assert(type(value) == "string", "second argument should be a string")
      assert(type(object) == "table", "third argument should be a table<object>")
      return object[propName] == value
    end
  end
end

return utils