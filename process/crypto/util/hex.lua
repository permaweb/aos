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

--- Converts a hex encoded string to its corresponding decoded string.
--- If the optional parameter `unsafe` is defined, it assumes that the hex string is well-formed
--- (no checks, no whitespace removal). By default, it removes whitespace (including newlines)
--- and checks that the hex string is well-formed.
--- 
--- @param hs string: The hex encoded string to be decoded.
--- @param unsafe boolean: (optional) If true, assumes the hex string is well-formed.
--- @return string, number: The decoded string.
local function hexToString(hs, unsafe)
	-- decode an hex encoded string. return the decoded string
	-- if optional parameter unsafe is defined, assume the hex
	-- string is well formed (no checks, no whitespace removal).
	-- Default is to remove white spaces (incl newlines)
	-- and check that the hex string is well formed
	local tonumber = tonumber
	if not unsafe then
		hs = string.gsub(hs, "%s+", "") -- remove whitespaces
		if string.find(hs, '[^0-9A-Za-z]') or #hs % 2 ~= 0 then
			error("invalid hex string")
		end
	end
	return hs:gsub(	'(%x%x)',
		function(c) return string.char(tonumber(c, 16)) end
		)
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
	hexToString = hexToString,
	ascii2hex = ascii2hex
}