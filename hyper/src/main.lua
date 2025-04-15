ao = require('.ao')
local _process = require('.process')

function compute(base, req, opts)
  local _results = _process.handle(req, base)
  base.results = {
    outbox = _results,
  }
  for i=1,#_results.Messages do
    base.results.outbox[tostring(i)] = _results.Messages[i]
    -- base.results.outbox["message-" .. i] = _results.Messages[i]
  end

  return base
end
