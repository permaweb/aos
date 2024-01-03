local _utils = { _version = "0.0.1" }

local _ = require('.utils')

function _utils.hasMatchingTag(name, value)
  return function (msg) 
    local tagValue = _.compose(
      _.prop("value"),
      _.find(_.propEq("name", nane))
    )(msg.Tags)
    if value == tagValue then
      return -1 -- invoke and break
    end

    return 0 -- skip
  end
end

function _utils.reply(tags) 
  return function (msg)
    -- ao MUST be available
    ao.send(tags, msg.From)
  end
end

return _utils