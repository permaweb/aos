-- Factory function for creating an "AOEvent"
local function AOEvent(initialData)
  if type(initialData) ~= "table" then
    error("AOEvent data must be a table.")
  end

  local event = {
    data = initialData or {},
    sampleRate = nil, -- Optional sample rate
  }

  local function isValidType(value)
    local valueType = type(value)
    return valueType == "string" or valueType == "number" or valueType == "boolean" or value == nil
  end

  function event:addField(key, value)
    if type(key) ~= "string" then
      error("Field key must be a string.")
    end
    if not isValidType(value) then
      error("Invalid field value type: " .. type(value) .. ". Supported types are string, number, boolean, or nil.")
    end
    self.data[key] = value
    return self
  end

  function event:addFields(fields)
    if type(fields) ~= "table" then
      error("Fields must be provided as a table.")
    end
    for key, value in pairs(fields) do
      self:addField(key, value)
    end
    return self
  end

  -- Helper function to escape JSON control characters in strings
  local function escapeString(s)
    -- Escape backslashes first
    s = string.gsub(s, '\\', '\\\\')
    -- Escape double quotes
    s = string.gsub(s, '"', '\\"')
    -- Escape other control characters (optional for full JSON compliance)
    s = string.gsub(s, '\n', '\\n')
    s = string.gsub(s, '\r', '\\r')
    s = string.gsub(s, '\t', '\\t')
    return s
  end

  function event:printEvent()
    local serializedData = "{"

    -- The _e: 1 flag signifies that this is an event
    serializedData = serializedData .. '"_e": 1, '

    -- Serialize event data
    for key, value in pairs(self.data) do
      local serializedValue

      if type(value) == "string" then
        serializedValue = '"' .. escapeString(value) .. '"'
      elseif type(value) == "number" or type(value) == "boolean" then
        serializedValue = tostring(value)
      elseif value == nil then
        serializedValue = "null"
      else
        error("Unsupported data type: " .. type(value))
      end

      serializedData = serializedData .. '"' .. key .. '": ' .. serializedValue .. ', '
    end

    -- Remove trailing comma and space, if any
    if string.sub(serializedData, -2) == ", " then
      serializedData = string.sub(serializedData, 1, -3)
    end

    serializedData = serializedData .. "}"

    print(serializedData)
  end

  return event
end

-- Return the AOEvent function to make it accessible from other files
return AOEvent
