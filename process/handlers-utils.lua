local _utils = { _version = "0.0.1" }

local _ = require('.utils')
local ao = require("ao")

function _utils.hasMatchingTag(name, value)
  assert(type(name) == 'string' and type(value) == 'string', 'invalid arguments: (name : string, value : string)')

  return function (msg) 
    if msg.Tags[name] == value then
      return -1
    end
    return 0
  end
end

function _utils.hasMatchingData(value)
  assert(type(value) == 'string', 'invalid arguments: (value : string)')
  return function (msg)
    if msg.Data == value then
      return -1
    end
    return 0
  end
end

function _utils.reply(input) 
  assert(type(input) == 'table' or type(input) == 'string', 'invalid arguments: (input : table or string)')
  return function (msg)
    if type(input) == 'string' then
      ao.send({Target = msg.From, Data = input})
      return
    end
    ao.send({Target = msg.From, Tags = input })
  end
end


return _utils