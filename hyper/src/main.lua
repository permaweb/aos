---@diagnostic disable lowercase-global
function compute(base, req, opts)
  local _process = require('.process')

  ao.event(base.process)
  ao.event(req.body)
  local _results = _process.handle(req, base)
  base.results = {
    info = "hyper-aos",
    outbox = {},
    output = _results.Output
  }
  for i=1,#_results.Messages do
    base.results.outbox[tostring(i)] = _results.Messages[i]
  end
  return base
end
