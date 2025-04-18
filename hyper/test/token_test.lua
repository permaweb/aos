local t = require('../apm_modules/@rakis/test-unit/source').new('hyper Token Blueprint')
local _print = print
-- load hyperAOS
require('../hyper-aos')
require('../blueprints/token')

local stringify = require('.stringify')

local function send_message(msg)
  local base = {
    process = {
      id = "1",
      commitments = { PROCESS = { alg = "rsa-pss-sha512", committer = "OWNER" }},
      authority = {"NETWORK1", "NETWORK2","OWNER"},
      type = "Process"
    }
  }
  local req = {
    path = "schedule",
    method = "POST",
    body = msg
  }
  return compute(base, req)
end

t:add('ok', function ()
  assert(true, 'success')
end)

t:add('mint token', function ()
  -- init with process message
  local base = send_message({
    commitments = { PROCESS = { alg = "rsa-pss-sha512", committer = "OWNER" }},
    target = "TOKEN",
    authority = {"NETWORK1", "NETWORK2","OWNER" },
    type = "Process"
  })
  assert(Inbox[1].body.type == "Process", 'added to inbox')
  -- send mint message
  base = send_message({
    target = "TOKEN",
    commitments = { MESSAGE = { alg = "rsa-pss-sha512", committer = "OWNER"}},
    action = "Mint",
    data = "Address1,1000\nAddress2,50",
    format = "CSV"

  })
  _print(stringify.format(base.results))
  assert(base.results.output.data == "Successfully processed mint request")
end)


t:add('send simple message', function ()
  local base = {
    process = {
      commitments = {
        OWNER = {
          alg = "rsa-pss-sha512"
        }
      }
    }
  }
  local req = {
    path = "schedule",
    method = "POST",
    body = {
      target = "1",
      data = "1 + 1",
      action = "Eval",
      commitments = {
        OWNER = {
          alg = "rsa-pss-sha512"
        }
      }
    }
  }
  base = compute(base, req)
  -- _print(require('.stringify').format(base.results))
  assert(base.results.output.data == "2", 'success')
end)


print(t:run())
