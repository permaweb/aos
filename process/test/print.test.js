import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: "wasm32-unknown-emscripten" }
test('multi print feature', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
  const msg = {
    Target: 'AOS',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'print("one") .. print("two")'
  }
  const result = await handle(null, msg, env)
  assert.equal(result.Output?.data.output, 'onetwo')
  assert.ok(true)
})

test('multi print feature via handler', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
  const msg = {
    Target: 'AOS',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'Handlers.add("ping", Handlers.utils.hasMatchingData("ping"), function (m) print(m.Data); print("pong") end)'
  }
  const { Memory } = await handle(null, msg, env)
  let msg2 = msg
  msg2.Tags = []
  msg2.Data = "ping"
  const result = await handle(Memory, msg2, env)
  assert.equal(result.Output.data, 'ping\npong')
  assert.ok(true)
})

test('Typos for functions should generate errors', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
  const msg = {
    Target: 'AOS',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'Handers.add("ping", Handlers.utils.hasMatchingData("ping"), function (m) print(m.Data); print("pong") end)'
  }
  const { Memory, Output, Error } = await handle(null, msg, env)

  let msg2 = msg
  msg2.Tags = [{ name: 'Action', value: 'Eval' }]
  msg2.Data = "Errors"
  const result = await handle(Memory, msg2, env)
  assert.equal(result.Output.data.output, '{ \x1B[32m"[string ".handlers"]:335: [string "aos"]:1: attempt to index a nil value (global \'Handers\')"\x1B[0m }')
  assert.ok(true)
})

