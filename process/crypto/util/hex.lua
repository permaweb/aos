-- Converts a string to its hexadecimal representation.
-- If the string is empty, it returns an empty string.
-- If the 'ln' parameter is not provided, it performs the conversion without adding newlines or separators.
-- If the 'ln' parameter is provided, it adds a newline character every 'ln' bytes.
-- The 'sep' parameter is an optional separator between each byte.
-- Returns the hexadecimal representation of the string.
local function stringToHex(s, ln, sep)
	if #s == 0 then return "" end
	if not ln then
		return (s:gsub('.',
			function(c) return string.format('%02x', string.byte(c)) end
		))
	end
	sep = sep or ""
	local t = {}
	for i = 1, #s - 1 do
		t[#t + 1] = string.format("%02x%s", s:byte(i),
			(i % ln == 0) and '\n' or sep)
	end
	t[#t + 1] = string.format("%02x", s:byte(#s))
	return table.concat(t)
end


local function ascii2hex(source)
  local ss = "";
  for i = 1,#source do
    ss = ss..string.format("%02X",source:byte(i,i));
  end
  return ss
end

return {
	stringToHex = stringToHex,
	ascii2hex = ascii2hex
}