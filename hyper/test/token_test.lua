local t = require('../apm_modules/@rakis/test-unit/source').new('hyper Token Blueprint')
local _print = print
-- load hyperAOS
require('../hyper-aos')
require('../blueprints/token')

local stringify = require('.stringify')

-- helper functions
--
-- sends message to process
local function send_message(msg, opts)
  opts = opts or {}
  local base = {
    process = {
      commitments = { PROCESS = { alg = "rsa-pss-sha512", committer = "OWNER" }},
      authority = {"NETWORK1", "NETWORK2","OWNER"},
      type = "Process"
    }
  }
  local req = {
    path = "schedule",
    method = "POST",
    slot = opts.slot or 1,
    timestamp = opts.timestamp or os.time(),
    ['block-height'] = opts.height or "1000",
    body = msg
  }
  return compute(base, req)
end

t:add('ok', function ()
  assert(true, 'success')
end)

t:add('get balances', function ()
  -- reset state
  Inbox = {}
  Balances = {}
  Initialized = nil

  -- send init msg
  local base = send_message({
    commitments = { PROCESS = { alg = "rsa-pss-sha512", committer = "OWNER" }},
    target = "TOKEN",
    authority = {"NETWORK1", "NETWORK2","OWNER" },
    type = "Process"
  }, { slot = 1})
  -- set balance
  Balances = { address1 = "59090", address2 = "10000" }
  base = send_message({
    commitments = { MSG = { alg = "rsa-pss-sha512", committer = "address1" }},
    target = "TOKEN",
    action = "Balances"
  })
  _print(stringify.format(base.results.outbox["1"]))
  assert(base.results.outbox["1"].mintedsupply == "69090", "should get balances")

end)

t:add('get info', function ()
  -- reset state
  Inbox = {}
  Balances = {}
  Initialized = nil

  -- send init msg
  local base = send_message({
    commitments = { PROCESS = { alg = "rsa-pss-sha512", committer = "OWNER" }},
    target = "TOKEN",
    authority = {"NETWORK1", "NETWORK2","OWNER" },
    type = "Process"
  }, { slot = 1})
  -- set balance
  Balances = { address1 = "59090" }
  base = send_message({
    commitments = { MSG = { alg = "rsa-pss-sha512", committer = "address1" }},
    target = "TOKEN",
    action = "Info"
  })

  assert(base.results.outbox["1"].name == "aos", "should get info")
end)

t:add('get balance', function ()
  -- reset state
  Inbox = {}
  Balances = {}
  Initialized = nil

  -- send init msg
  local base = send_message({
    commitments = { PROCESS = { alg = "rsa-pss-sha512", committer = "OWNER" }},
    target = "TOKEN",
    authority = {"NETWORK1", "NETWORK2","OWNER" },
    type = "Process"
  }, { slot = 1})
  -- set balance
  Balances = { address1 = "59090" }
  base = send_message({
    commitments = { MSG = { alg = "rsa-pss-sha512", committer = "address1" }},
    target = "TOKEN",
    action = "Balance"
  })
  assert(base.results.outbox["1"].data == "59090", "should get callers balance")
end)

t:add('mint token', function ()
  -- reset state
  Inbox = {}
  Balances = {}
  Initialized = nil
  -- init with process message
  local base = send_message({
    commitments = { PROCESS = { alg = "rsa-pss-sha512", committer = "OWNER" }},
    target = "TOKEN",
    authority = {"NETWORK1", "NETWORK2","OWNER" },
    type = "Process"
  }, { slot = 1 })
  assert(Inbox[1].body.type == "Process", 'added to inbox')
  -- send mint message
  base = send_message({
    target = "TOKEN",
    commitments = { MESSAGE = { alg = "rsa-pss-sha512", committer = "OWNER"}},
    action = "Mint",
    data = "Address1,1000\nAddress2,50",
    format = "CSV"

  }, {slot = 2})
  assert(base.results.output.data == "Successfully processed mint request")
end)


t:add('send simple message', function ()
  local base = {
    process = {
      commitments = {
        PROCESS = {
          alg = "rsa-pss-sha512",
          committer = "OWNER"
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
        MSG = {
          alg = "rsa-pss-sha512",
          committer = "OWNER"
        }
      }
    }
  }
  base = compute(base, req)
  -- _print(require('.stringify').format(base.results))
  assert(base.results.output.data == "2", 'success')
end)


print(t:run())
