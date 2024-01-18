-- stringify is a function that converts a lua table to a string representation

local stringify = { _version = "0.0.1" }

function stringify.format(tbl)
  local result = {}
  local isArray = true
  local arrayIndex = 1

  for k, v in pairs(tbl) do
      if isArray then
          if k == arrayIndex then
              arrayIndex = arrayIndex + 1
              if type(v) == "table" then
                v = stringify.format(v)
              elseif type(v) == "string" then
                v = '"' .. v .. '"'
              else 
                v = tostring(v)
              end
              table.insert(result, v)
          else
              isArray = false
              result = {}
          end
      end
      if not isArray then
          if type(v) == "table" then
            v = stringify.format(v)
          elseif type(v) == "string" then
            v = '"' .. v .. '"'
          else 
            v = tostring(v)
          end
          table.insert(result, k .. " = " .. v)
      end
  end

  local prefix = isArray and "{" or "{ "
  local suffix = isArray and "}" or " }"
  local separator = isArray and "," or ", "
  return prefix .. table.concat(result, separator) .. suffix
end

return stringify