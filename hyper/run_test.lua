Test = require('./apm_modules/@rakis/test-unit/source')
-- load aos

_G.package.loaded['.utils'] = require('./src/utils')
_G.package.loaded['.handlers-utils'] = require('./src/handlers-utils')
_G.package.loaded['.handlers'] = require('./src/handlers')
_G.package.loaded['.ao'] = require('./src/ao')
_G.package.loaded['.stringify'] = require('./src/stringify')
local _print = print
_G.package.loaded['.state'] = require('./src/state')
print = _print
local t = Test.new('HyperAOS Test Suite')

local utils = require('.utils')

---@diagnostic disable lowercase-global
ao = ao or {}
ao.event = function (desc)
  _print(desc)
end

t:add('utils.matchesSpec', function ()
  assert(utils.matchesSpec({ action = "Balance"}, "Balance"), 'should match shallow action')
  assert(utils.matchesSpec({ body = { action = "Balance" }}, "Balance"), 'should match body action')

  assert(utils.matchesSpec({ body = { method = "beep" }}, { method = "beep" }), 'should match method')
end)

local result = t:run()

print(result)
