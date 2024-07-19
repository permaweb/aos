import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }

test('magictable to wrap send to convert data to json', async () => {
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
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'Send({ Target = "AOS", Data = { foo = "bar" }})'
  }
  const result = await handle(null, msg, env)
  assert.equal(result.Messages[0].Data, '{"foo":"bar"}')
  const msg2 = Object.assign({}, msg, result.Messages[0])
  const tableResult = await handle(result.Memory, msg2, env)
  const inboxResult = await handle(
    tableResult.Memory,
    Object.assign({}, msg, { Tags: [{ name: 'Action', value: 'Eval' }], Data: 'Inbox[1].Data.foo' }),
    env
  )
  assert.equal(inboxResult.Output.data, 'bar')
})

test('magictable to wrap swap to convert data to json', async () => {
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
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'Spawn("AWESOME_SAUCE", { Target = "TEST", Data = { foo = "bar" }})'
  }
  const result = await handle(null, msg, env)
  assert.equal(result.Spawns[0].Data, '{"foo":"bar"}')
})
