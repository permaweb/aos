--- The Pretty module provides a utility for printing Lua tables in a more readable format.
-- @module pretty

--- The pretty module
-- @table pretty
-- @field _version The version number of the pretty module
-- @field tprint The tprint function
local pretty = { _version = "0.0.1" }

--- Prints a table with indentation for better readability.
-- @function tprint
-- @tparam {table} tbl The table to print
-- @tparam {number} indent The indentation level (default is 0)
-- @treturn {string} A string representation of the table with indentation
pretty.tprint = function (tbl, indent)
  if not indent then indent = 0 end
  local output = ""
  for k, v in pairs(tbl) do
    local formatting = string.rep(" ", indent) .. k .. ": "
    if type(v) == "table" then
      output = output .. formatting .. "\n"
      output = output .. pretty.tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      output = output .. formatting .. tostring(v) .. "\n"
    else
      output = output .. formatting .. v .. "\n"
    end
  end
  return output
end

return pretty