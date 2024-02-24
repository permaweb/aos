import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')

test('ping pong', async () => {
  const handle = await AoLoader(wasm)
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
  const handle = await AoLoader(wasm)
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
  assert.equal(result.Output.data, 'one\ntwo')
  assert.ok(true)
})