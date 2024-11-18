--- The AO module provides functionality for managing the AO environment and handling messages. Returns the ao table.
-- @module ao

local oldao = ao or {}

--- The AO module
-- @table ao
-- @field _version The version number of the ao module
-- @field _module The module id of the process
-- @field id The id of the process
-- @field authorities A table of authorities of the process
-- @field reference The reference number of the process
-- @field outbox The outbox of the process
-- @field nonExtractableTags The non-extractable tags
-- @field nonForwardableTags The non-forwardable tags
-- @field clone The clone function
-- @field normalize The normalize function
-- @field sanitize The sanitize function
-- @field init The init function
-- @field log The log function
-- @field clearOutbox The clearOutbox function
-- @field send The send function
-- @field spawn The spawn function
-- @field assign The assign function
-- @field isTrusted The isTrusted function
-- @field result The result function
local ao = {
    _version = "0.0.6",
    id = oldao.id or "",
    _module = oldao._module or "",
    authorities = oldao.authorities or {},
    reference = oldao.reference or 0,
    outbox = oldao.outbox or
        {Output = {}, Messages = {}, Spawns = {}, Assignments = {}},
    nonExtractableTags = {
        'Data-Protocol', 'Variant', 'From-Process', 'From-Module', 'Type',
        'From', 'Owner', 'Anchor', 'Target', 'Data', 'Tags', 'Read-Only'
    },
    nonForwardableTags = {
        'Data-Protocol', 'Variant', 'From-Process', 'From-Module', 'Type',
        'From', 'Owner', 'Anchor', 'Target', 'Tags', 'TagArray', 'Hash-Chain',
        'Timestamp', 'Nonce', 'Epoch', 'Signature', 'Forwarded-By',
        'Pushed-For', 'Read-Only', 'Cron', 'Block-Height', 'Reference', 'Id',
        'Reply-To'
    }
}

--- Checks if a key exists in a list.
-- @lfunction _includes
-- @tparam {table} list The list to check against
-- @treturn {function} A function that takes a key and returns true if the key exists in the list
local function _includes(list)
    return function(key)
        local exists = false
        for _, listKey in ipairs(list) do
            if key == listKey then
                exists = true
                break
            end
        end
        if not exists then return false end
        return true
    end
end

--- Checks if a table is an array.
-- @lfunction isArray
-- @tparam {table} table The table to check
-- @treturn {boolean} True if the table is an array, false otherwise
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

--- Pads a number with leading zeros to 32 digits.
-- @lfunction padZero32
-- @tparam {number} num The number to pad
-- @treturn {string} The padded number as a string
local function padZero32(num) return string.format("%032d", num) end

--- Clones a table recursively.
-- @function clone
-- @tparam {any} obj The object to clone
-- @tparam {table} seen The table of seen objects (default is nil)
-- @treturn {any} The cloned object
function ao.clone(obj, seen)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end

    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do res[ao.clone(k, s)] = ao.clone(v, s) end
    return setmetatable(res, getmetatable(obj))
end

--- Normalizes a message by extracting tags.
-- @function normalize
-- @tparam {table} msg The message to normalize
-- @treturn {table} The normalized message
function ao.normalize(msg)
    for _, o in ipairs(msg.Tags) do
        if not _includes(ao.nonExtractableTags)(o.name) then
            msg[o.name] = o.value
        end
    end
    return msg
end

--- Sanitizes a message by removing non-forwardable tags.
-- @function sanitize
-- @tparam {table} msg The message to sanitize
-- @treturn {table} The sanitized message
function ao.sanitize(msg)
    local newMsg = ao.clone(msg)

    for k, _ in pairs(newMsg) do
        if _includes(ao.nonForwardableTags)(k) then newMsg[k] = nil end
    end

    return newMsg
end

--- Initializes the AO environment, including ID, module, authorities, outbox, and environment.
-- @function init
-- @tparam {table} env The environment object
function ao.init(env)
    if ao.id == "" then ao.id = env.Process.Id end

    if ao._module == "" then
        for _, o in ipairs(env.Process.Tags) do
            if o.name == "Module" then ao._module = o.value end
        end
    end

    if #ao.authorities < 1 then
        for _, o in ipairs(env.Process.Tags) do
            if o.name == "Authority" then
                table.insert(ao.authorities, o.value)
            end
        end
    end

    ao.outbox = {Output = {}, Messages = {}, Spawns = {}, Assignments = {}}
    ao.env = env

end

--- Logs a message to the output.
-- @function log
-- @tparam {string} txt The message to log
function ao.log(txt)
    if type(ao.outbox.Output) == 'string' then
        ao.outbox.Output = {ao.outbox.Output}
    end
    table.insert(ao.outbox.Output, txt)
end

--- Clears the outbox.
-- @function clearOutbox
function ao.clearOutbox()
    ao.outbox = {Output = {}, Messages = {}, Spawns = {}, Assignments = {}}
end

--- Sends a message.
-- @function send
-- @tparam {table} msg The message to send
function ao.send(msg)
    assert(type(msg) == 'table', 'msg should be a table')
    ao.reference = ao.reference + 1
    local referenceString = tostring(ao.reference)

    local message = {
        Target = msg.Target,
        Data = msg.Data,
        Anchor = padZero32(ao.reference),
        Tags = {
            {name = "Data-Protocol", value = "ao"},
            {name = "Variant", value = "ao.TN.1"},
            {name = "Type", value = "Message"},
            {name = "Reference", value = referenceString}
        }
    }

    -- if custom tags in root move them to tags
    for k, v in pairs(msg) do
        if not _includes({"Target", "Data", "Anchor", "Tags", "From"})(k) then
            table.insert(message.Tags, {name = k, value = v})
        end
    end

    if msg.Tags then
        if isArray(msg.Tags) then
            for _, o in ipairs(msg.Tags) do
                table.insert(message.Tags, o)
            end
        else
            for k, v in pairs(msg.Tags) do
                table.insert(message.Tags, {name = k, value = v})
            end
        end
    end

    -- If running in an environment without the AOS Handlers module, do not add
    -- the onReply and receive functions to the message.
    if not Handlers then return message end

    -- clone message info and add to outbox
    local extMessage = {}
    for k, v in pairs(message) do extMessage[k] = v end

    -- add message to outbox
    table.insert(ao.outbox.Messages, extMessage)

    -- add callback for onReply handler(s)
    message.onReply =
        function(...) -- Takes either (AddressThatWillReply, handler(s)) or (handler(s))
            local from, resolver
            if select("#", ...) == 2 then
                from = select(1, ...)
                resolver = select(2, ...)
            else
                from = message.Target
                resolver = select(1, ...)
            end

            -- Add a one-time callback that runs the user's (matching) resolver on reply
            Handlers.once({From = from, ["X-Reference"] = referenceString},
                          resolver)
        end

    message.receive = function(...)
        local from = message.Target
        if select("#", ...) == 1 then from = select(1, ...) end
        return
            Handlers.receive({From = from, ["X-Reference"] = referenceString})
    end

    return message
end

--- Spawns a process.
-- @function spawn
-- @tparam {string} module The module source id
-- @tparam {table} msg The message to send
function ao.spawn(module, msg)
    assert(type(module) == "string", "Module source id is required!")
    assert(type(msg) == 'table', 'Message must be a table')
    -- inc spawn reference
    ao.reference = ao.reference + 1
    local spawnRef = tostring(ao.reference)

    local spawn = {
        Data = msg.Data or "NODATA",
        Anchor = padZero32(ao.reference),
        Tags = {
            {name = "Data-Protocol", value = "ao"},
            {name = "Variant", value = "ao.TN.1"},
            {name = "Type", value = "Process"},
            {name = "From-Process", value = ao.id},
            {name = "From-Module", value = ao._module},
            {name = "Module", value = module},
            {name = "Reference", value = spawnRef}
        }
    }

    -- if custom tags in root move them to tags
    for k, v in pairs(msg) do
        if not _includes({"Target", "Data", "Anchor", "Tags", "From"})(k) then
            table.insert(spawn.Tags, {name = k, value = v})
        end
    end

    if msg.Tags then
        if isArray(msg.Tags) then
            for _, o in ipairs(msg.Tags) do
                table.insert(spawn.Tags, o)
            end
        else
            for k, v in pairs(msg.Tags) do
                table.insert(spawn.Tags, {name = k, value = v})
            end
        end
    end

    -- If running in an environment without the AOS Handlers module, do not add
    -- the after and receive functions to the spawn.
    if not Handlers then return spawn end

    -- clone spawn info and add to outbox
    local extSpawn = {}
    for k, v in pairs(spawn) do extSpawn[k] = v end

    table.insert(ao.outbox.Spawns, extSpawn)

    -- add 'after' callback to returned table
    -- local result = {}
    spawn.onReply = function(callback)
        Handlers.once({
            Action = "Spawned",
            From = ao.id,
            ["Reference"] = spawnRef
        }, callback)
    end

    spawn.receive = function()
        return Handlers.receive({
            Action = "Spawned",
            From = ao.id,
            ["Reference"] = spawnRef
        })

    end

    return spawn
end

--- Assigns a message to a process.
-- @function assign
-- @tparam {table} assignment The assignment to assign
function ao.assign(assignment)
    assert(type(assignment) == 'table', 'assignment should be a table')
    assert(type(assignment.Processes) == 'table', 'Processes should be a table')
    assert(type(assignment.Message) == "string", "Message should be a string")
    table.insert(ao.outbox.Assignments, assignment)
end

--- Checks if a message is trusted.
-- The default security model of AOS processes: Trust all and *only* those on the ao.authorities list.
-- @function isTrusted
-- @tparam {table} msg The message to check
-- @treturn {boolean} True if the message is trusted, false otherwise
function ao.isTrusted(msg)
    for _, authority in ipairs(ao.authorities) do
        if msg.From == authority then return true end
        if msg.Owner == authority then return true end
    end
    return false
end

--- Returns the result of the process.
-- @function result
-- @tparam {table} result The result of the process
-- @treturn {table} The result of the process, including Output, Messages, Spawns, and Assignments
function ao.result(result)
    -- if error then only send the Error to CU
    if ao.outbox.Error or result.Error then
        return {Error = result.Error or ao.outbox.Error}
    end
    return {
        Output = result.Output or ao.outbox.Output,
        Messages = ao.outbox.Messages,
        Spawns = ao.outbox.Spawns,
        Assignments = ao.outbox.Assignments
    }
end


--- Add the MatchSpec to the ao.assignables table. A optional name may be provided.
-- This implies that ao.assignables may have both number and string indices.
-- Added in the assignment module.
-- @function addAssignable
-- @tparam ?string|number|any nameOrMatchSpec The name of the MatchSpec
--        to be added to ao.assignables. if a MatchSpec is provided, then
--        no name is included
-- @tparam ?any matchSpec The MatchSpec to be added to ao.assignables. Only provided
--        if its name is passed as the first parameter
-- @treturn ?string|number name The name of the MatchSpec, either as provided
--          as an argument or as incremented
-- @see assignment

--- Remove the MatchSpec, either by name or by index
-- If the name is not found, or if the index does not exist, then do nothing.
-- Added in the assignment module.
-- @function removeAssignable
-- @tparam {string|number} name The name or index of the MatchSpec to be removed
-- @see assignment

--- Return whether the msg is an assignment or not. This can be determined by simply check whether the msg's Target is this process' id
-- Added in the assignment module.
-- @function isAssignment
-- @param msg The msg to be checked
-- @treturn boolean isAssignment
-- @see assignment

--- Check whether the msg matches any assignable MatchSpec.
-- If not assignables are configured, the msg is deemed not assignable, by default.
-- Added in the assignment module.
-- @function isAssignable
-- @param msg The msg to be checked
-- @treturn boolean isAssignable
-- @see assignment

return ao
