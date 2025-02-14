local base64 = require(".src.base64")
local crypto = require(".crypto.init")
local json = require(".src.json")
local constants = require(".src.constants")
local utils = {}

function utils.hasMatchingTag(tag, value)
	return Handlers.utils.hasMatchingTag(tag, value)
end

--- Checks if a value is an integer
--- @param value any The value to check
--- @return boolean isInteger - whether the value is an integer
function utils.isInteger(value)
	if value == nil then
		return false
	end
	if type(value) == "string" then
		value = tonumber(value)
	end
	return type(value) == "number" and value % 1 == 0
end

--- Rounds a number to a given precision
--- @param number number The number to round
--- @param precision number The precision to round to
--- @return number roundedNumber - the rounded number to the precision provided
function utils.roundToPrecision(number, precision)
	return math.floor(number * (10 ^ precision) + 0.5) / (10 ^ precision)
end

--- Sums the values of a table
--- @param tbl table The table to sum
--- @return number sum - the sum of the table values
function utils.sumTableValues(tbl)
	local sum = 0
	for _, value in pairs(tbl) do
		assert(type(value) == "number", "Table values must be numbers. Found: " .. type(value))
		sum = sum + value
	end
	return sum
end

--- Slices a table
--- @param tbl table The table to slice
--- @param first number The first index to slice from
--- @param last number|nil The last index to slice to
--- @param step number|nil The step to slice by
--- @return table slicedTable - the sliced table
function utils.slice(tbl, first, last, step)
	local sliced = {}

	for i = first or 1, last or #tbl, step or 1 do
		sliced[#sliced + 1] = tbl[i]
	end

	return sliced
end

--- @class PaginationTags
--- @field cursor string|nil The cursor to paginate from
--- @field limit number The limit of results to return
--- @field sortBy string|nil The field to sort by
--- @field sortOrder string The order to sort by

--- Parses the pagination tags from a message
--- @param msg table The message provided to a handler (see ao docs for more info)
--- @return PaginationTags paginationTags - the pagination tags
function utils.parsePaginationTags(msg)
	local cursor = msg.Tags.Cursor
	local limit = tonumber(msg.Tags["Limit"]) or 100

	assert(limit <= 1000, "Limit must be less than or equal to 1000")

	local sortOrder = msg.Tags["Sort-Order"] and string.lower(msg.Tags["Sort-Order"]) or "desc"
	local sortBy = msg.Tags["Sort-By"]
	return {
		cursor = cursor,
		limit = limit,
		sortBy = sortBy,
		sortOrder = sortOrder,
	}
end

--- Sorts a table by multiple fields with specified orders for each field.
--- Supports tables of non-table values by using `nil` as a field name.
--- Each field is provided as a table with 'field' (string|nil) and 'order' ("asc" or "desc").
--- Supports nested fields using dot notation.
--- @param prevTable table The table to sort
--- @param fields table A list of fields with order specified, e.g., { { field = "name", order = "asc" } }
--- @return table sortedTable - the sorted table
function utils.sortTableByFields(prevTable, fields)
	-- Handle sorting for non-table values with possible nils
	if fields[1].field == nil then
		-- Separate non-nil values and count nil values
		local nonNilValues = {}
		local nilValuesCount = 0

		for _, value in pairs(prevTable) do -- Use pairs instead of ipairs to include all elements
			if value == nil then
				nilValuesCount = nilValuesCount + 1
			else
				table.insert(nonNilValues, value)
			end
		end

		-- Sort non-nil values
		table.sort(nonNilValues, function(a, b)
			if fields[1].order == "asc" then
				return a < b
			else
				return a > b
			end
		end)

		-- Append nil values to the end
		for _ = 1, nilValuesCount do
			table.insert(nonNilValues, nil)
		end

		return nonNilValues
	end

	-- Deep copy for sorting complex nested values
	local tableCopy = utils.deepCopy(prevTable) or {}

	-- If no elements or no fields, return the copied table as-is
	if #tableCopy == 0 or #fields == 0 then
		return tableCopy
	end

	-- Helper function to retrieve a nested field value by path
	local function getNestedValue(tbl, fieldPath)
		local current = tbl
		for segment in fieldPath:gmatch("[^.]+") do
			if type(current) == "table" then
				current = current[segment]
			else
				return nil
			end
		end
		return current
	end

	-- Sort table using table.sort with multiple fields and specified orders
	table.sort(tableCopy, function(a, b)
		for _, fieldSpec in ipairs(fields) do
			local fieldPath = fieldSpec.field
			local order = fieldSpec.order
			local aField, bField

			-- Check if field is nil, treating a and b as simple values
			if fieldPath == nil then
				aField = a
				bField = b
			else
				aField = getNestedValue(a, fieldPath)
				bField = getNestedValue(b, fieldPath)
			end

			-- Validate order
			if order ~= "asc" and order ~= "desc" then
				error("Invalid sort order. Expected 'asc' or 'desc'")
			end

			-- Handle nil values to ensure they go to the end
			if aField == nil and bField ~= nil then
				return false
			elseif aField ~= nil and bField == nil then
				return true
			elseif aField ~= nil and bField ~= nil then
				-- Compare based on the specified order
				if aField ~= bField then
					if order == "asc" then
						return aField < bField
					else
						return aField > bField
					end
				end
			end
		end
		-- All fields are equal
		return false
	end)

	return tableCopy
end

--- @class PaginatedTable
--- @field items table The items in the current page
--- @field limit number The limit of items to return
--- @field totalItems number The total number of items
--- @field sortBy string|nil The field to sort by, nil if sorting by the primitive items themselves
--- @field sortOrder string The order to sort by
--- @field nextCursor string|number|nil The cursor to the next page
--- @field hasMore boolean Whether there is a next page

--- Paginate a table with a cursor
--- @param tableArray table The table to paginate
--- @param cursor string|number|nil The cursor to paginate from (optional)
--- @param cursorField string|nil The field to use as the cursor or nil for lists of primitives
--- @param limit number The limit of items to return
--- @param sortBy string|nil The field to sort by. Nil if sorting by the primitive items themselves.
--- @param sortOrder string The order to sort by ("asc" or "desc")
--- @return PaginatedTable paginatedTable - the paginated table result
function utils.paginateTableWithCursor(tableArray, cursor, cursorField, limit, sortBy, sortOrder)
	local sortedArray = utils.sortTableByFields(tableArray, { { order = sortOrder, field = sortBy } })

	if not sortedArray or #sortedArray == 0 then
		return {
			items = {},
			limit = limit,
			totalItems = 0,
			sortBy = sortBy,
			sortOrder = sortOrder,
			nextCursor = nil,
			hasMore = false,
		}
	end

	local startIndex = 1

	if cursor then
		for i, obj in ipairs(sortedArray) do
			if cursorField and obj[cursorField] == cursor or cursor == obj then
				startIndex = i + 1
				break
			end
		end
	end

	local items = {}
	local endIndex = math.min(startIndex + limit - 1, #sortedArray)

	for i = startIndex, endIndex do
		table.insert(items, sortedArray[i])
	end

	local nextCursor = nil
	if endIndex < #sortedArray then
		nextCursor = cursorField and sortedArray[endIndex][cursorField] or sortedArray[endIndex]
	end

	return {
		items = items,
		limit = limit,
		totalItems = #sortedArray,
		sortBy = sortBy,
		sortOrder = sortOrder,
		nextCursor = nextCursor, -- the last item in the current page
		hasMore = nextCursor ~= nil,
	}
end

--- Checks if an address is a valid Arweave address
--- @param address string The address to check
--- @return boolean # whether the address is a valid Arweave address
function utils.isValidArweaveAddress(address)
	return type(address) == "string" and #address == 43 and string.match(address, "^[%w-_]+$") ~= nil
end

--- Checks if an address looks like an unformatted Ethereum address
--- @param address string The address to check
--- @return boolean isValidUnformattedEthAddress - whether the address is a valid unformatted Ethereum address
function utils.isValidUnformattedEthAddress(address)
	return type(address) == "string" and #address == 42 and string.match(address, "^0x[%x]+$") ~= nil
end

--- Checks if an address is a valid Ethereum address and is in EIP-55 checksum format
--- @param address string The address to check
--- @return boolean isValidEthAddress - whether the address is a valid Ethereum address
function utils.isValidEthAddress(address)
	return utils.isValidUnformattedEthAddress(address) and address == utils.formatEIP55Address(address)
end

function utils.isValidUnsafeAddress(address)
	if not address then
		return false
	end
	local match = string.match(address, "^[%w_-]+$")
	return match ~= nil
		and #address >= constants.MIN_UNSAFE_ADDRESS_LENGTH
		and #address <= constants.MAX_UNSAFE_ADDRESS_LENGTH
end

--- Checks if an address is a valid AO address
--- @param address string|nil The address to check
--- @param allowUnsafe boolean|nil Whether to allow unsafe addresses, defaults to false
--- @return boolean # whether the address is valid, depending on the allowUnsafe flag
function utils.isValidAddress(address, allowUnsafe)
	allowUnsafe = allowUnsafe or false -- default to false, only allow unsafe addresses if explicitly set
	if not address then
		return false
	end
	if allowUnsafe then
		return utils.isValidUnsafeAddress(address)
	end
	return utils.isValidArweaveAddress(address) or utils.isValidEthAddress(address)
end

--- Converts an address to EIP-55 checksum format
--- Assumes address has been validated as a valid Ethereum address (see utils.isValidEthAddress)
--- Reference: https://eips.ethereum.org/EIPS/eip-55
--- @param address string The address to convert
--- @return string formattedAddress - the EIP-55 checksum formatted address
function utils.formatEIP55Address(address)
	local hex = string.lower(string.sub(address, 3))

	local hash = crypto.digest.keccak256(hex)
	local hashHex = hash.asHex()

	local checksumAddress = "0x"

	for i = 1, #hashHex do
		local hexChar = string.sub(hashHex, i, i)
		local hexCharValue = tonumber(hexChar, 16)
		local char = string.sub(hex, i, i)
		if hexCharValue > 7 then
			char = string.upper(char)
		end
		checksumAddress = checksumAddress .. char
	end

	return checksumAddress
end

--- Formats an address to EIP-55 checksum format if it is a valid Ethereum address
--- @param address string The address to format
--- @return string formattedAddress - the EIP-55 checksum formatted address
function utils.formatAddress(address)
	if utils.isValidUnformattedEthAddress(address) then
		return utils.formatEIP55Address(address)
	end
	return address
end

--- Safely decodes a JSON string
--- @param jsonString string|nil The JSON string to decode
--- @return table|nil decodedJson - the decoded JSON or nil if the string is nil or the decoding fails
function utils.safeDecodeJson(jsonString)
	if not jsonString then
		return nil
	end
	local status, result = pcall(json.decode, jsonString)
	if not status then
		return nil
	end
	return result
end

--- Finds an element in an array that matches a predicate
--- @param array table The array to search
--- @param predicate function The predicate to match
--- @return number|nil index - the index of the found element or nil if the element is not found
function utils.findInArray(array, predicate)
	for i = 1, #array do
		if predicate(array[i]) then
			return i -- Return the index of the found element
		end
	end
	return nil -- Return nil if the element is not found
end

--- Deep copies a table with optional exclusion of specified fields, including nested fields
--- Preserves proper sequential ordering of array tables when some of the excluded nested keys are array indexes
--- @generic T: table|nil
--- @param original T The table to copy
--- @param excludedFields table|nil An array of keys or dot-separated key paths to exclude from the deep copy
--- @return T The deep copy of the table or nil if the original is nil
function utils.deepCopy(original, excludedFields)
	if not original then
		return nil
	end

	if type(original) ~= "table" then
		return original
	end

	-- Fast path: If no excluded fields, copy directly
	if not excludedFields or #excludedFields == 0 then
		local copy = {}
		for key, value in pairs(original) do
			if type(value) == "table" then
				copy[key] = utils.deepCopy(value) -- Recursive copy for nested tables
			else
				copy[key] = value
			end
		end
		return copy
	end

	-- If excludes are provided, create a lookup table for excluded fields
	local excluded = utils.createLookupTable(excludedFields)

	-- Helper function to check if a key path is excluded
	local function isExcluded(keyPath)
		for excludedKey in pairs(excluded) do
			if keyPath == excludedKey or keyPath:match("^" .. excludedKey .. "%.") then
				return true
			end
		end
		return false
	end

	-- Recursive function to deep copy with nested field exclusion
	local function deepCopyHelper(orig, path)
		if type(orig) ~= "table" then
			return orig
		end

		local result = {}
		local isArray = true

		-- Check if all keys are numeric and sequential
		for key in pairs(orig) do
			if type(key) ~= "number" or key % 1 ~= 0 then
				isArray = false
				break
			end
		end

		if isArray then
			-- Collect numeric keys in sorted order for sequential reindexing
			local numericKeys = {}
			for key in pairs(orig) do
				table.insert(numericKeys, key)
			end
			table.sort(numericKeys)

			local index = 1
			for _, key in ipairs(numericKeys) do
				local keyPath = path and (path .. "." .. key) or tostring(key)
				if not isExcluded(keyPath) then
					result[index] = deepCopyHelper(orig[key], keyPath) -- Sequentially reindex
					index = index + 1
				end
			end
		else
			-- Handle non-array tables (dictionaries)
			for key, value in pairs(orig) do
				local keyPath = path and (path .. "." .. key) or key
				if not isExcluded(keyPath) then
					result[key] = deepCopyHelper(value, keyPath)
				end
			end
		end

		return result
	end

	-- Use the exclusion-aware deep copy helper
	return deepCopyHelper(original, nil)
end

--- Gets the length of a table
--- @param table table The table to get the length of
--- @return number length - the length of the table
function utils.lengthOfTable(table)
	local count = 0
	for _, val in pairs(table) do
		if val then
			count = count + 1
		end
	end
	return count
end

--- Gets a hash from a base64 URL encoded string
--- @param str string The base64 URL encoded string
--- @return table The hash
function utils.getHashFromBase64URL(str)
	local decodedHash = base64.decode(str, base64.URL_DECODER)
	local hashStream = crypto.utils.stream.fromString(decodedHash)
	return crypto.digest.sha2_256(hashStream).asBytes()
end

--- Escapes Lua pattern characters in a string
--- @param str string The string to escape
--- @return string # The escaped string
local function escapePattern(str)
	return (str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

--- Splits a string by a delimiter
--- @param input string The string to split
--- @param delimiter string|nil The delimiter to split by
--- @return table # The split string
function utils.splitString(input, delimiter)
	delimiter = delimiter or ","
	delimiter = escapePattern(delimiter)
	local result = {}
	for token in (input or ""):gmatch(string.format("([^%s]+)", delimiter)) do
		table.insert(result, token)
	end
	return result
end

--- Trims a string
--- @param input string The string to trim
--- @return string The trimmed string
function utils.trimString(input)
	return input:match("^%s*(.-)%s*$")
end

--- Splits a string by a delimiter and trims each token
--- @param input string|nil The string to split
--- @param delimiter string|nil The delimiter to split by, defaults to ","
--- @return table tokens - the split and trimmed string
function utils.splitAndTrimString(input, delimiter)
	delimiter = escapePattern(delimiter or ",")
	if not input then
		return {}
	end
	local tokens = {}
	for _, token in ipairs(utils.splitString(input, delimiter)) do
		local trimmed = utils.trimString(token)
		if #trimmed > 0 then
			table.insert(tokens, trimmed)
		end
	end
	return tokens
end

--- Checks if a timestamp is an integer and converts it to milliseconds if it is in seconds
--- @param timestamp number The timestamp to check and convert
--- @return number timestampInMs - the timestamp in milliseconds
function utils.checkAndConvertTimestampToMs(timestamp)
	-- Check if the timestamp is an integer
	assert(type(timestamp) == "number", "Timestamp must be a number")
	assert(utils.isInteger(timestamp), "Timestamp must be an integer")

	-- Define the plausible range for Unix timestamps in seconds
	local min_timestamp = 0
	local max_timestamp = 4102444800 -- Corresponds to 2100-01-01

	if timestamp >= min_timestamp and timestamp <= max_timestamp then
		-- The timestamp is already in seconds, convert it to milliseconds
		return timestamp * 1000
	end

	-- If the timestamp is outside the range for seconds, check for milliseconds
	local min_timestamp_ms = min_timestamp * 1000
	local max_timestamp_ms = max_timestamp * 1000

	if timestamp >= min_timestamp_ms and timestamp <= max_timestamp_ms then
		return timestamp
	end

	error("Timestamp is out of range")
end

function utils.reduce(tbl, fn, init)
	local acc = init
	local i = 1
	for k, v in pairs(tbl) do
		acc = fn(acc, k, v, i)
		i = i + 1
	end
	return acc
end

function utils.map(tbl, fn)
	local newTbl = {}
	for k, v in pairs(tbl) do
		newTbl[k] = fn(k, v)
	end
	return newTbl
end

function utils.toTrainCase(str)
	-- Replace underscores and spaces with hyphens
	str = str:gsub("[_%s]+", "-")

	-- Handle camelCase and PascalCase by adding a hyphen before uppercase letters that follow lowercase letters
	str = str:gsub("(%l)(%u)", "%1-%2")

	-- Capitalize the first letter of every word (after hyphen) and convert to Train-Case
	str = str:gsub("(%a)([%w]*)", function(first, rest)
		-- If the word is all uppercase (like "GW"), preserve it
		if first:upper() == first and rest:upper() == rest then
			return first:upper() .. rest
		else
			return first:upper() .. rest:lower()
		end
	end)
	return str
end

function utils.createLookupTable(tbl, valueFn)
	local lookupTable = {}
	valueFn = valueFn or function()
		return true
	end
	for key, value in pairs(tbl or {}) do
		lookupTable[value] = valueFn(key, value)
	end
	return lookupTable
end

function utils.getTableKeys(tbl)
	local keys = {}
	for key, _ in pairs(tbl or {}) do
		table.insert(keys, key)
	end
	return keys
end

function utils.filterArray(arr, predicate)
	local filtered = {}
	for i, value in ipairs(arr or {}) do -- ipairs ensures we only traverse numeric keys sequentially
		if predicate and predicate(i, value) then
			table.insert(filtered, value) -- Insert re-indexes automatically
		end
	end
	return filtered
end

function utils.filterDictionary(tbl, predicate)
	local filtered = {}
	for key, value in pairs(tbl or {}) do
		if predicate and predicate(key, value) then
			filtered[key] = value
		end
	end
	return filtered
end

--- Sanitizes inputs to ensure they are valid strings
--- @param table table The table to sanitize
--- @return table sanitizedTable - the sanitized table
function utils.validateAndSanitizeInputs(table)
	assert(type(table) == "table", "Table must be a table")
	local sanitizedTable = {}
	for key, value in pairs(table) do
		assert(type(key) == "string", "Key must be a string")
		assert(
			type(value) == "string" or type(value) == "number" or type(value) == "boolean",
			"Value must be a string, integer, or boolean"
		)
		if type(value) == "string" then
			assert(#key > 0, "Key cannot be empty")
			assert(#value > 0, "Value cannot be empty")
			assert(not string.match(key, "^%s+$"), "Key cannot be only whitespace")
			assert(not string.match(value, "^%s+$"), "Value cannot be only whitespace")
		end
		if type(value) == "boolean" then
			assert(value == true or value == false, "Boolean value must be true or false")
		end
		if type(value) == "number" then
			assert(utils.isInteger(value), "Number must be an integer")
		end
		sanitizedTable[key] = value
	end

	local knownAddressTags = {
		"Recipient",
		"Initiator",
		"Target",
		"Source",
		"Address",
		"Vault-Id",
		"Process-Id",
		"Observer-Address",
	}

	for _, tagName in ipairs(knownAddressTags) do
		-- Format all incoming addresses
		sanitizedTable[tagName] = sanitizedTable[tagName] and utils.formatAddress(sanitizedTable[tagName]) or nil
	end

	local knownNumberTags = {
		"Quantity",
		"Lock-Length",
		"Operator-Stake",
		"Delegated-Stake",
		"Withdraw-Stake",
		"Timestamp",
		"Years",
		"Min-Delegated-Stake",
		"Port",
		"Extend-Length",
		"Delegate-Reward-Share-Ratio",
		"Epoch-Index",
		"Price-Interval-Ms",
		"Block-Height",
	}
	for _, tagName in ipairs(knownNumberTags) do
		-- Format all incoming numbers
		sanitizedTable[tagName] = sanitizedTable[tagName] and tonumber(sanitizedTable[tagName]) or nil
	end

	local knownBooleanTags = {
		"Allow-Unsafe-Addresses",
		"Force-Prune",
		"Revokable",
	}
	for _, tagName in ipairs(knownBooleanTags) do
		sanitizedTable[tagName] = sanitizedTable[tagName]
				and utils.booleanOrBooleanStringToBoolean(sanitizedTable[tagName])
			or nil
	end
	return sanitizedTable
end

--- @param value string|boolean
--- @return boolean
function utils.booleanOrBooleanStringToBoolean(value)
	if type(value) == "boolean" then
		return value
	end
	return type(value) == "string" and string.lower(value) == "true"
end

return utils
