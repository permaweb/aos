
local Assignment = { _version = "0.1.0" }
local utils = require('.utils')

-- Implement assignable polyfills on _ao
function Assignment.init (ao)
  local function findIndexByProp(array, prop, value)
    for index, object in ipairs(array) do
      if object[prop] == value then return index end
    end

    return nil
  end

  ao.assignables = ao.assignables or {}

  -- Add the MatchSpec to the ao.assignables table. A optional name may be provided.
  -- This implies that ao.assignables may have both number and string indices.
  --
  -- @tparam ?string|number|any nameOrMatchSpec The name of the MatchSpec
  --        to be added to ao.assignables. if a MatchSpec is provided, then
  --        no name is included
  -- @tparam ?any matchSpec The MatchSpec to be added to ao.assignables. Only provided
  --        if its name is passed as the first parameter
  -- @treturn ?string|number name The name of the MatchSpec, either as provided
  --          as an argument or as incremented
  ao.addAssignable = ao.addAssignable or function (...)
    local name = nil
    local matchSpec = nil

    local idx = nil

    -- Initialize the parameters based on arguments
    if select("#", ...) == 1 then
      matchSpec = select(1, ...)
    else
      name = select(1, ...)
      matchSpec = select(2, ...)
      assert(type(name) == 'string', 'MatchSpec name MUST be a string')
    end

    if name then idx = findIndexByProp(ao.assignables, "name", name) end

    if idx ~= nil and idx > 0 then
      -- found update
      ao.assignables[idx].pattern = matchSpec
    else
      -- append the new assignable, including potentially nil name
      table.insert(ao.assignables, { pattern = matchSpec, name = name })
    end
  end

  -- Remove the MatchSpec, either by name or by index
  -- If the name is not found, or if the index does not exist, then do nothing.
  --
  -- @tparam string|number name The name or index of the MatchSpec to be removed
  -- @treturn nil nil
  ao.removeAssignable = ao.removeAssignable or function (name)
    local idx = nil

    if type(name) == 'string' then idx = findIndexByProp(ao.assignables, "name", name)
    else
      assert(type(name) == 'number', 'index MUST be a number')
      idx = name
    end

    if idx == nil or idx <= 0 or idx > #ao.assignables then return end

    table.remove(ao.assignables, idx)
  end

  -- Return whether the msg is an assignment or not. This
  -- can be determined by simply check whether the msg's Target is
  -- This process' id
  --
  -- @param msg The msg to be checked
  -- @treturn boolean isAssignment
  ao.isAssignment = ao.isAssignment or function (msg) return msg.Target ~= ao.id end

  -- Check whether the msg matches any assignable MatchSpec.
  -- If not assignables are configured, the msg is deemed not assignable, by default.
  --
  -- @param msg The msg to be checked
  -- @treturn boolean isAssignable
  ao.isAssignable = ao.isAssignable or function (msg)
    for _, assignable in pairs(ao.assignables) do
      if utils.matchesSpec(msg, assignable.pattern) then return true end
    end

    -- If assignables is empty, the the above loop will noop,
    -- and this expression will execute.
    --
    -- In other words, all msgs are not assignable, by default.
    return false
  end
end

return Assignment
