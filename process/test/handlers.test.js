import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: "wasm32-unknown-emscripten" }
test('ping pong', async () => {
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
    Data: `
Handlers.add("ping", 
  Handlers.utils.hasMatchingData("ping"), 
  function (Msg) 
    print("pong")
  end
)
    `
  }
  // load handler
  const { Memory } = await handle(null, msg, env)
  // ---
  const ping = {
    Target: 'AOS',
    Owner: 'FRED',
    Tags: [],
    Data: 'ping'
  }
  const result = await handle(Memory, ping, env)
  assert.equal(result.Output.data, 'pong')
  assert.ok(true)
})

test('handler pipeline', async () => {
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
    Data: `
Handlers.add("one", 
  function (Msg)
    return "continue"
  end, 
  function (Msg) 
    print("one")
  end
)

Handlers.add("two", 
  function (Msg)
    return "continue"
  end, 
  function (Msg) 
    print("two")
  end
)

Handlers.add("three", 
  function (Msg)
    return "skip"
  end, 
  function (Msg) 
    print("three")
  end
)

    `
  }
  // load handler
  const { Memory } = await handle(null, msg, env)
  // ---
  const ping = {
    Target: 'AOS',
    Owner: 'FRED',
    Tags: [],
    Data: 'ping'
  }
  const result = await handle(Memory, ping, env)
  assert.equal(result.Output.data, 'one\ntwo\n\x1B[90mNew Message From \x1B[32munknown\x1B[90m: \x1B[90mData = \x1B[34mping\x1B[0m')
  assert.ok(true)
})