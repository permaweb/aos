local utils = require(".src.utils")
local json = require(".src.json")

--- @class AOEvent
--- @field data table<string, any> The data table holding the event fields.
--- @field sampleRate number|nil Optional sample rate.
--- @field addField fun(self: AOEvent, key: string, value: any): AOEvent Adds a single field to the event.
--- @field addFields fun(self: AOEvent, fields: table<string, any>): AOEvent Adds multiple fields to the event.
--- @field addFieldsIfExist fun(self: AOEvent, table: table<string, any>|nil, fields: table<string>): AOEvent Adds specific fields if they exist in the given table.
--- @field addFieldsWithPrefixIfExist fun(self: AOEvent, srcTable: table<string, any>, prefix: string, fields: table<string>): AOEvent
---  Adds fields with a prefix if they exist in the source table.
--- @field printEvent fun(self: AOEvent): nil Prints the event in JSON format.
--- @field toJSON fun(self: AOEvent): string Converts the event to a JSON string.

--- Factory function for creating an "AOEvent"
--- @param initialData table<string, any> Optional initial data to populate the event with.
--- @returns AOEvent
local function AOEvent(initialData)
	local event = {
		sampleRate = nil, -- Optional sample rate
	}

	if type(initialData) ~= "table" then
		print("ERROR: AOEvent data must be a table.")
		event.data = {}
	else
		event.data = initialData
	end

	local function isValidTableValueType(value)
		local valueType = type(value)
		return valueType == "string" or valueType == "number" or valueType == "boolean" or value == nil
	end

	local function isValidType(value)
		local valueType = type(value)
		if isValidTableValueType(value) then
			return true
		elseif valueType == "table" then
			-- Prevent nested tables
			for _, v in pairs(value) do
				if not isValidTableValueType(v) then
					return false
				end
			end
			return true
		end
		return false
	end

	--- Add a field to the event
	--- @param key string The key to add to the event.
	--- @param value any The value to add to the event.
	--- @param trainCase boolean|nil Whether to convert the key to Train Case. Defaults to true.
	function event:addField(key, value, trainCase)
		trainCase = trainCase ~= false -- default to true unless explicitly set to false
		if type(key) ~= "string" then
			print("ERROR: Field key must be a string.")
			return self
		end
		if not isValidType(value) then
			print(
				"ERROR: Invalid field value type: "
					.. type(value)
					.. ". Supported types are string, number, boolean, or nil."
			)
			if type(value) == "table" then
				print("Invalid field value: " .. require(".json").encode(value))
			end
			return self
		end
		self.data[trainCase and utils.toTrainCase(key) or key] = value
		return self
	end

	function event:addFields(fields)
		if type(fields) ~= "table" then
			print("ERROR: Fields must be provided as a table.")
			return self
		end
		for key, value in pairs(fields) do
			self:addField(key, value)
		end
		return self
	end

	function event:addFieldsIfExist(table, fields)
		table = table == nil and {} or table -- allow for nil OR a table, but not other falsey value types
		if type(table) ~= "table" then
			print("ERROR: Table and fields must be provided as tables.")
			return self
		end
		for _, key in pairs(fields) do
			if table[key] then
				self:addField(key, table[key])
			end
		end
		return self
	end

	function event:addFieldsWithPrefixIfExist(srcTable, prefix, fields)
		srcTable = srcTable == nil and {} or srcTable -- allow for nil OR a table, but not other falsey value types
		if type(srcTable) ~= "table" or type(fields) ~= "table" then
			print("ERROR: table and fields must be provided as a table.")
			return self
		end
		for _, key in pairs(fields) do
			if srcTable[key] ~= nil then
				self:addField(prefix .. key, srcTable[key])
			end
		end
		return self
	end

	function event:printEvent()
		print(self:toJSON())
	end

	function event:toJSON()
		-- The _e: 1 flag signifies that this is an event. Ensure it is set.
		self.data["_e"] = 1
		return json.encode(self.data)
	end

	return event
end

-- Return the AOEvent function to make it accessible from other files
return AOEvent
