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

test.skip('inbox unbounded', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const msg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Data: 'Hello',
    Tags: []
  }
  const result = await handle(start, msg, env)
  let memory = result.Memory
  for (var i = 0; i < 10001; i++) {
    const { Memory } = await handle(memory, msg, env)
    memory = Memory
  }
  const count = await handle(memory, {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [{ name: 'Action', value: 'Eval' }],
    Data: '#Inbox'
  }, env)
  //assert.equal(count.Error, 'Error')
  assert.equal(count.Output?.data, "10000")
  assert.ok(true)
})

