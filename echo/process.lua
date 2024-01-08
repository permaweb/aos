local process = { _version = "0.0.1" }
local dump = require ".dump"

function process.handle(msg, ao)   
  msg.foo = function(n)
    return n
  end


  return {
    Output = dump(msg),
    Messages = {},
    Spawns = {}
  }
end

return process
