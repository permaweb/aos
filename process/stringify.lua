local stringify = { _version = "0.0.1" }

-- ANSI color codes
local colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m"
}

function stringify.isSimpleArray(tbl)
  local arrayIndex = 1
  for k, v in pairs(tbl) do
    if k ~= arrayIndex or (type(v) ~= "number" and type(v) ~= "string") then
      return false
    end
    arrayIndex = arrayIndex + 1
  end
  return true
end

function stringify.format(tbl, indent)
  indent = indent or 0
  local toIndent = string.rep(" ", indent)
  local toIndentChild = string.rep(" ", indent + 2)

  local result = {}
  local isArray = true
  local arrayIndex = 1

  if stringify.isSimpleArray(tbl) then
    for _, v in ipairs(tbl) do
      if type(v) == "string" then
        v = colors.green .. '"' .. v .. '"' .. colors.reset
      else
        v = colors.blue .. tostring(v) .. colors.reset
      end
      table.insert(result, v)
    end
    return "{ " .. table.concat(result, ", ") .. " }"
  end

  for k, v in pairs(tbl) do
    if isArray then
      if k == arrayIndex then
        arrayIndex = arrayIndex + 1
        if type(v) == "table" then
          v = stringify.format(v, indent + 2)
        elseif type(v) == "string" then
          v = colors.green .. '"' .. v .. '"' .. colors.reset
        else
          v = colors.blue .. tostring(v) .. colors.reset
        end
        table.insert(result, toIndentChild .. v)
      else
        isArray = false
        result = {}
      end
    end
    if not isArray then
      if type(v) == "table" then
        v = stringify.format(v, indent + 2)
      elseif type(v) == "string" then
        v = colors.green .. '"' .. v .. '"' .. colors.reset
      else
        v = colors.blue .. tostring(v) .. colors.reset
      end
      k = colors.red .. k .. colors.reset
      table.insert(result, toIndentChild .. k .. " = " .. v)
    end
  end

  local prefix = isArray and "{\n" or "{\n "
  local suffix = isArray and "\n" .. toIndent .. " }" or "\n" .. toIndent .. "}"
  local separator = isArray and ",\n" or ",\n "
  return prefix .. table.concat(result, separator) .. suffix
end

return stringify
