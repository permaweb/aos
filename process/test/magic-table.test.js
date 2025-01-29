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

test('magictable to wrap send to convert data to json', async () => {
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
    Data: 'Send({ Target = "AOS", Data = { foo = "bar" }})'
  }
  const result = await handle(start, msg, env)
  assert.equal(result.Messages[0].Data, '{"foo":"bar"}')
  const msg2 = Object.assign({}, msg, result.Messages[0])
  const tableResult = await handle(result.Memory, msg2, env)
  
  const inboxResult = await handle(
    tableResult.Memory,
    Object.assign({}, msg, { Tags: [{ name: 'Action', value: 'Eval' }], Data: 'Inbox[2].Data.foo' }),
    env
  )
  console.log(inboxResult)
  assert.equal(inboxResult.Output.data, 'bar')
})

test('magictable to wrap swap to convert data to json', async () => {
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
    Data: 'Spawn("AWESOME_SAUCE", { Target = "TEST", Data = { foo = "bar" }})'
  }
  const result = await handle(start, msg, env)
  assert.equal(result.Spawns[0].Data, '{"foo":"bar"}')
})
