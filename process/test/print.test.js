import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }

const env = {
  Process: {
    Id: 'AOS',
    Owner: 'FOOBAR',
    Tags: [
      { name: 'Name', value: 'Thomas' }
    ]
  }
}

async function init(handle) {
  const {Memory} = await handle(null, {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    'Block-Height': '999',
    Id: 'AOS',
    Module: 'WOOPAWOOPA',
    Tags: [
      { name: 'Name', value: 'Thomas' }
    ]
  }, env)
  return Memory
}

test('multi print feature', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const msg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: `
print("one") 
print("two")
`
  }
  const result = await handle(start, msg, env)
  assert.equal(result.Output?.data, 'one\ntwo')
  assert.ok(true)
})

test('multi print feature via handler', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)

  const msg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'Handlers.add("ping", Handlers.utils.hasMatchingData("ping"), function (m) print(m.Data); print("pong") end)'
  }
  const { Memory } = await handle(start, msg, env)
  let msg2 = msg
  msg2.Tags = []
  msg2.Data = "ping"
  const result = await handle(Memory, msg2, env)
  assert.equal(result.Output.data, 'ping\npong')
  assert.ok(true)
})

test('Typos for functions should generate errors', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const msg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'Handers.add("ping", Handlers.utils.hasMatchingData("ping"), function (m) print(m.Data); print("pong") end)'
  }
  const { Memory, Output, Error } = await handle(start, msg, env)

  let msg2 = msg
  msg2.Tags = [{ name: 'Action', value: 'Eval' }]
  msg2.Data = "Errors"
  const result = await handle(Memory, msg2, env)
  assert.ok(result.Output.data.includes("attempt to index a nil value (global \'Handers\')"))
})

test('Print Errors in Handlers', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const msg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'Handlers.add("ping", Handlers.utils.hasMatchingData("ping"), function (m) print(m.Data); print("pong" .. x) end)'
  }
  const { Memory, Output, Error } = await handle(null, msg, env)

  let msg2 = msg
  msg2.Tags = []
  msg2.Data = "ping"
  const result = await handle(Memory, msg2, env)

  assert.ok(result.Error.includes('handling message'))
  assert.ok(true)
})

test('print nil should not add newline to output', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const msg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'print(nil)'
  }
  const result = await handle(start, msg, env)
  // When printing nil, it should output "nil" (colored) but no extra newlines
  assert.ok(result.Output?.data.includes('nil'))
  assert.ok(!result.Output?.data.includes('\n'))
})

test('handler with no print should not produce extra newline', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)

  // First, add a handler that doesn't print anything
  const setupMsg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'Handlers.add("test", Handlers.utils.hasMatchingData("test"), function (m) local x = 1 + 1 end)'
  }
  const { Memory } = await handle(start, setupMsg, env)

  // Now send a message that triggers the handler
  const triggerMsg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1001",
    Id: "5678abcd",
    Module: "WOOPAWOOPA",
    Tags: [],
    Data: "test"
  }
  const result = await handle(Memory, triggerMsg, env)
  
  // Should have empty output data, no extra newlines
  assert.equal(result.Output?.data, '')
})
