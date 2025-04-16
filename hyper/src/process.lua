ao = ao or require('.ao')
Handlers = require('.handlers')
Utils = require('.utils')
Dump = require('.dump')

local process = { _version = "2.0.7" }
local state = require('.state')
local eval = require('.eval')
local default = require('.default')
local json = require('.json')

function Prompt()
  return "aos> "
end

function process.handle(req, base)
  HandlerPrintLogs = state.reset(HandlerPrintLogs)
  os.time = function () return tonumber(req['block-timestamp']) end

  ao.init(base)
  -- initialize state
  state.init(req, base)

  -- magic table
  req.body.data = req.body['Content-Type'] == 'application/json'
    and json.decode(req.body.data or "{}")
    or req.body.data

  Errors = Errors or {}
  -- clear outbox
  ao.clearOutbox()

  -- state.checkSlot(msg, ao)
  Handlers.add("_eval", function (_req)
    local function getMsgFrom(m)
      local from = ""
      Utils.map(
        function (k)
          local c = m.commitments[k]
          if c.alg == "rsa-pss-sha512" then
            from = c.committer
          end
        end,
        Utils.keys(m.commitments)
      )
      return from
    end
    return _req.body.action == "Eval" and Owner == getMsgFrom(_req.body)
  end, eval(ao))

  Handlers.add("_default",
    function () return true end,
    default(state.insertInbox)
  )

  local status, error = pcall(Handlers.evaluate, req, base)

  -- cleanup handlers so that they are always at the end of the pipeline
  Handlers.remove("_eval")
  Handlers.remove("_default")

  local printData = table.concat(HandlerPrintLogs, "\n")
  if not status then
    if req.body.action == "Eval" then
      table.insert(Errors, error)
      return {
        Error = table.concat({
          printData,
          "\n",
          Colors.red,
          "error: " .. error,
          Colors.reset,
        })
      }
    end
    print(Colors.red .. "Error" .. Colors.gray .. " handling message " .. Colors.reset)
    print(Colors.green .. error .. Colors.reset)
    print("\n" .. Colors.gray .. debug.traceback() .. Colors.reset)
    return ao.result({
      Error = printData .. '\n\n' .. Colors.red .. 'error:\n' .. Colors.reset .. error,
      Messages = {},
      Spawns = {},
      Assignments = {}
    })
  end

  local response = {}

  if req.body.action == "Eval" then
    response = ao.result({
      output = {
        data = printData,
        prompt = Prompt()
      }
    })
  else
    response = ao.result({
      output = {
        data = printData,
        prompt = Prompt(),
        print = true
      }
    })
  end

  HandlerPrintLogs = state.reset(HandlerPrintLogs) -- clear logs
  -- ao.Slot = msg.Slot
  return response
end

function Version()
  print("version: " .. process._version)
end

return process
