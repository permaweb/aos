local process = { _version = "0.0.1" }

function process.handle(msg, ao)   
  return {
    Output = "Hello",
    Messages = {},
    Spawns = {}
  }
end

return process
