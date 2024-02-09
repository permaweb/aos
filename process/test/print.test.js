import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')

test('multi print feature', async () => {
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
    Data: 'print("one") .. print("two")'
  }
  const result = await handle(null, msg, env)
  assert.equal(result.Output?.data.output, 'onetwo')
  assert.ok(true)
})

test('multi print feature via handler', async () => {
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

