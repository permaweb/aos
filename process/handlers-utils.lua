local _utils = { _version = "0.0.1" }

local _ = require('.utils')

function _utils.hasMatchingTag(name, value)
  return function (msg) 
    if msg.Tags[name] == value then
      return -1
    end
    return 0
  end
end

function _utils.reply(tags) 
  return function (msg)
    ao.send({Target = msg.From, Tags = tags })
  end
end

return _utils