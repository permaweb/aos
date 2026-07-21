import { spawnSync } from 'node:child_process'
import { test } from 'node:test'
import assert from 'node:assert'

import {
  LUA_PROCESS_OUTPUT_PATCH,
  processVersionExpression
} from '../../src/services/lua-process-patch.js'

test('process version handshake only patches Lua device processes', () => {
  const luaExpression = processVersionExpression('lua@5.3')

  assert.match(luaExpression, /function send\(msg\)/)
  assert.match(luaExpression, /return "Message Sent"/)
  assert.match(luaExpression, /return require\('\.process'\)\._version/)
  assert.strictEqual(
    processVersionExpression('genesis-wasm'),
    "return require('.process')._version"
  )
})

const luaAvailable = spawnSync('lua', ['-v'], { encoding: 'utf8' }).status === 0

test(
  'Lua compatibility patch formats sends and incoming actions',
  {
    skip: luaAvailable ? false : 'lua is not installed'
  },
  () => {
    const harness = `
_OUTPUT = ""
results = { outbox = {}, output = { prompt = "hyper[0]> " } }
colors = { green = "", blue = "", reset = "" }
meta = {}
Inbox = {}

function prompt()
  return "hyper[" .. tostring(#Inbox) .. "]> "
end

function print(value)
  _OUTPUT = _OUTPUT .. tostring(value) .. "\\n"
end

function eval()
  print("force update")
  return nil
end

Handlers = {
  evaluate = function(msg)
    table.insert(Inbox, msg)
    print(meta.printNewMessage(msg))
    return true
  end
}

${LUA_PROCESS_OUTPUT_PATCH}
${LUA_PROCESS_OUTPUT_PATCH}

local acknowledgement = send({ target = "process-b", action = "hello" })
assert(acknowledgement == "Message Sent")
assert(#results.outbox == 1)
assert(results.outbox[1].action == "hello")

_OUTPUT = ""
local notification = Handlers.evaluate({
  from = "inHNKIXpul10F-OS2l-d6Zkm4ms5DgIPLye1Q22QH_s",
  action = "hello"
}, {})

assert(notification == "New Message From inH...H_s: Action = hello")
assert(_OUTPUT == "")
assert(not string.find(notification, "true", 1, true))
assert(results.output.prompt == "hyper[1]> ")

notification = Handlers.evaluate({ From = "proc-b", Action = "Hello-Again" }, {})
assert(notification == "New Message From proc-b: Action = Hello-Again")
assert(results.output.prompt == "hyper[2]> ")

_OUTPUT = ""
local eval_result = eval({ data = "print('force update')" })
assert(eval_result == "")
assert(_OUTPUT == "force update\\n")
`
    const result = spawnSync('lua', ['-'], { input: harness, encoding: 'utf8' })

    assert.strictEqual(result.status, 0, result.stderr || result.stdout)
  }
)
