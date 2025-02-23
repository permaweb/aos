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
      { name: 'Name', value: 'Thomas' },
    ],
    Data: ''
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
      { name: 'Action', value: 'Eval' },
      { name: 'Hint', value: 'https://the.ao.computer'},
    ],
    Data: `
print("one") 
print("two")
Send({Target = ao.id, Action = "Hint" })
`
  }
  const result = await handle(start, msg, env)
  assert.equal(result.Output?.data, 'one\ntwo')
  assert.ok(result.Messages[0].Tags.find(t => t.name === "From-Process").value == "AOS?hint=https://the.ao.computer")
  assert.ok(true)
  console.log(result.Messages[0].Tags)
})

test('multi print feature - no hint', async () => {
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
      { name: 'Action', value: 'Eval' },
    ],
    Data: `
print("one") 
print("two")
Send({Target = ao.id, Action = "Hint" })
`
  }
  const result = await handle(start, msg, env)
  assert.equal(result.Output?.data, 'one\ntwo')
  assert.ok(result.Messages[0].Tags.find(t => t.name === "From-Process").value == "AOS")
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
