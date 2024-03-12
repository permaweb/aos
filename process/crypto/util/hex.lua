
--- Converts a string to its hexadecimal representation.
--- @param s string The input string.
--- @param ln? number - The number of characters per line. If not provided, the output will be a single line.
--- @param sep? string - The separator between each pair of hexadecimal characters. Defaults to an empty string.
--- @return string The - hexadecimal representation of the input string.
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
--- @param hs (string) The hex encoded string to be decoded.
--- @param unsafe (boolean) [optional] If true, assumes the hex string is well-formed.
--- @return (string) The decoded string.
local function hexToString(hs, unsafe)
	local tonumber = tonumber
	if not unsafe then
		hs = string.gsub(hs, "%s+", "") -- remove whitespaces
		if string.find(hs, '[^0-9A-Za-z]') or #hs % 2 ~= 0 then
			error("invalid hex string")
		end
	end
	local count =  string.gsub(hs, '(%x%x)',function(c) return string.char(tonumber(c, 16)) end)
	return count
end

return {
	stringToHex = stringToHex,
	hexToString = hexToString,
}