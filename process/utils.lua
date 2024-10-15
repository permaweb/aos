local utils = { _version = "0.0.5" }

function utils.matchesPattern(pattern, value, msg)
	-- If the key is not in the message, then it does not match
	if not pattern then
		return false
	end
	-- if the patternMatchSpec is a wildcard, then it always matches
	if pattern == "_" then
		return true
	end
	-- if the patternMatchSpec is a function, then it is executed on the tag value
	if type(pattern) == "function" then
		if pattern(value, msg) then
			return true
		else
			return false
		end
	end

	-- if the patternMatchSpec is a string, check it for special symbols (less `-` alone)
	-- and exact string match mode
	if type(pattern) == "string" then
		if string.match(pattern, "[%^%$%(%)%%%.%[%]%*%+%?]") then
			if string.match(value, pattern) then
				return true
			end
		else
			if value == pattern then
				return true
			end
		end
	end

	-- if the pattern is a table, recursively check if any of its sub-patterns match
	if type(pattern) == "table" then
		for _, subPattern in pairs(pattern) do
			if utils.matchesPattern(subPattern, value, msg) then
				return true
			end
		end
	end

	return false
end

function utils.matchesSpec(msg, spec)
	if type(spec) == "function" then
		return spec(msg)
		-- If the spec is a table, step through every key/value pair in the pattern and check if the msg matches
		-- Supported pattern types:
		--   - Exact string match
		--   - Lua gmatch string
		--   - '_' (wildcard: Message has tag, but can be any value)
		--   - Function execution on the tag, optionally using the msg as the second argument
		--   - Table of patterns, where ANY of the sub-patterns matching the tag will result in a match
	end
	if type(spec) == "table" then
		for key, pattern in pairs(spec) do
			if not msg[key] then
				return false
			end
			if not utils.matchesPattern(pattern, msg[key], msg) then
				return false
			end
		end
		return true
	end
	if type(spec) == "string" and msg.Action and msg.Action == spec then
		return true
	end
	return false
end

local function isArray(table)
	if type(table) == "table" then
		local maxIndex = 0
		for k, v in pairs(table) do
			if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
				return false -- If there's a non-integer key, it's not an array
			end
			maxIndex = math.max(maxIndex, k)
		end
		-- If the highest numeric index is equal to the number of elements, it's an array
		return maxIndex == #table
	end
	return false
end

-- @param {function} fn
-- @param {number} arity
utils.curry = function(fn, arity)
	assert(type(fn) == "function", "function is required as first argument")
	arity = arity or debug.getinfo(fn, "u").nparams
	if arity < 2 then
		return fn
	end

	return function(...)
		local args = { ... }

		if #args >= arity then
			return fn(table.unpack(args))
		else
			return utils.curry(function(...)
				return fn(table.unpack(args), ...)
			end, arity - #args)
		end
	end
end

--- Concat two Array Tables.
-- @param {table<Array>} a
-- @param {table<Array>} b
utils.concat = utils.curry(function(a, b)
	assert(type(a) == "table", "first argument should be a table that is an array")
	assert(type(b) == "table", "second argument should be a table that is an array")
	assert(isArray(a), "first argument should be a table")
	assert(isArray(b), "second argument should be a table")

	local result = {}
	for i = 1, #a do
		result[#result + 1] = a[i]
	end
	for i = 1, #b do
		result[#result + 1] = b[i]
	end
	return result
	--return table.concat(a,b)
end, 2)

--- reduce applies a function to a table
-- @param {function} fn
-- @param {any} initial
-- @param {table<Array>} t
utils.reduce = utils.curry(function(fn, initial, t)
	assert(type(fn) == "function", "first argument should be a function that accepts (result, value, key)")
	assert(type(t) == "table" and isArray(t), "third argument should be a table that is an array")
	local result = initial
	for k, v in pairs(t) do
		if result == nil then
			result = v
		else
			result = fn(result, v, k)
		end
	end
	return result
end, 3)

-- @param {function} fn
-- @param {table<Array>} data
utils.map = utils.curry(function(fn, data)
	assert(type(fn) == "function", "first argument should be a unary function")
	assert(type(data) == "table" and isArray(data), "second argument should be an Array")

	local function map(result, v, k)
		result[k] = fn(v, k)
		return result
	end

	return utils.reduce(map, {}, data)
end, 2)

-- @param {function} fn
-- @param {table<Array>} data
utils.filter = utils.curry(function(fn, data)
	assert(type(fn) == "function", "first argument should be a unary function")
	assert(type(data) == "table" and isArray(data), "second argument should be an Array")

	local function filter(result, v, _k)
		if fn(v) then
			table.insert(result, v)
		end
		return result
	end

	return utils.reduce(filter, {}, data)
end, 2)

-- @param {function} fn
-- @param {table<Array>} t
utils.find = utils.curry(function(fn, t)
	assert(type(fn) == "function", "first argument should be a unary function")
	assert(type(t) == "table", "second argument should be a table that is an array")
	for _, v in pairs(t) do
		if fn(v) then
			return v
		end
	end
end, 2)

-- @param {string} propName
-- @param {string} value
-- @param {table} object
utils.propEq = utils.curry(function(propName, value, object)
	assert(type(propName) == "string", "first argument should be a string")
	-- assert(type(value) == "string", "second argument should be a string")
	assert(type(object) == "table", "third argument should be a table<object>")

	return object[propName] == value
end, 3)

-- @param {table<Array>} data
utils.reverse = function(data)
	assert(type(data) == "table", "argument needs to be a table that is an array")
	return utils.reduce(function(result, v, i)
		result[#data - i + 1] = v
		return result
	end, {}, data)
end

-- @param {function} ...
utils.compose = utils.curry(function(...)
	local mutations = utils.reverse({ ... })

	return function(v)
		local result = v
		for _, fn in pairs(mutations) do
			assert(type(fn) == "function", "each argument needs to be a function")
			result = fn(result)
		end
		return result
	end
end, 2)

-- @param {string} propName
-- @param {table} object
utils.prop = utils.curry(function(propName, object)
	return object[propName]
end, 2)

-- @param {any} val
-- @param {table<Array>} t
utils.includes = utils.curry(function(val, t)
	assert(type(t) == "table", "argument needs to be a table")
	return utils.find(function(v)
		return v == val
	end, t) ~= nil
end, 2)

-- @param {table} t
utils.keys = function(t)
	assert(type(t) == "table", "argument needs to be a table")
	local keys = {}
	for key in pairs(t) do
		table.insert(keys, key)
	end
	return keys
end

-- @param {table} t
utils.values = function(t)
	assert(type(t) == "table", "argument needs to be a table")
	local values = {}
	for _, value in pairs(t) do
		table.insert(values, value)
	end
	return values
end

utils.parseFunctionCode = function(fn)
	assert(type(fn) == "function", "argument needs to be a function")
	-- Get debug information about the function
	local info = debug.getinfo(fn)

	if not info then
		return
	end

	local sourceString = info.source
	local startLine = info.linedefined
	local endLine = info.lastlinedefined

	-- Split the source string into lines
	local lines = {}
	for line in sourceString:gmatch("([^\r\n]*)\r?\n?") do
		table.insert(lines, line)
	end

	-- Extract the function code
	local code = ""
  if #lines < endLine - startLine then
    -- this means the source is not available, just the short source
    code = sourceString
  else
    for i = startLine, endLine do
      if lines[i] then
        code = code .. lines[i] .. "\n"
      end
    end
  end


	return code
end

utils.parseCoroutine = function(co)
	assert(type(co) == "thread", "argument needs to be a coroutine")
	local status = coroutine.status(co)
	local stackTrace = debug.traceback(co)

	-- Retrieve function details from the coroutine (if available)
	local coFunctionInfo = debug.getinfo(co, 0)
	local functionSourceOk, functionSource = pcall(utils.parseFunctionCode, coFunctionInfo.func)

	return {
		status = status,
		stackTrace = stackTrace,
		functionSource = functionSourceOk and functionSource or "Failed to retrieve function source",
	}
end

-- Central parsing function for all types
utils.parseValue = function(value, visited)
    visited = visited or {}

    if type(value) == "function" then
        local success, funcCode = pcall(utils.parseFunctionCode, value)
        return success and funcCode or "Failed to parse function"
    elseif type(value) == "thread" then
        return utils.parseCoroutine(value)
    elseif type(value) == "table" then
        -- Avoid circular references
        if visited[value] then
            return "<circular reference>"
        end
        visited[value] = true
        local result = {}
        for k, v in pairs(value) do
            -- Handle non-string keys as in previous example
            local key
            if type(k) == "string" then
                key = k
            else
                key = tostring(k)
            end
            result[key] = utils.parseValue(v, visited)
        end
        return result
    elseif type(value) == "userdata" then
        return "<userdata>"  -- Userdata cannot be serialized, handle as string
    elseif type(value) == "number" then
        -- Check for 'inf', '-inf', or 'nan' and handle them
        if value == math.huge then
            return "inf"  -- Convert 'inf' to a string
        elseif value == -math.huge then
            return "-inf"  -- Convert '-inf' to a string
        elseif value ~= value then  -- Check for 'nan'
            return "NaN"  -- Convert 'NaN' to a string
        else
            return value  -- Regular numbers are fine for JSON
        end
    elseif type(value) == "boolean" or type(value) == "string" then
        return value  -- Safe for serialization
    else
        return "<unsupported type>"  -- Any other unsupported types
    end
end


utils.getProgramState = function()
	local packages = {}
	local visitedTables = {}

	-- Parse loaded packages
	for packageName, loadedPackage in pairs(package.loaded) do
		if packageName ~= "package" and packageName ~= "_G" then
      packages[packageName] = utils.parseValue(loadedPackage, visitedTables)
      end
		-- This handles packages regardless of whether they are functions, tables, etc.
		-- Circular references are also managed automatically.
		end

	-- Parse global variables
	local globals = utils.parseValue(_G, {})

	return {
		packages = packages,
		globals = globals,
	}
end


return utils
