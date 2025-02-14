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
      { name: 'Name', value: 'Thomas' },
      { name: 'Authority', value: 'FOOBAR' }
    ]
  }
}

async function init(handle) {
  const result = await handle(null, {
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
  return result.Memory
}

test('return process info', async () => {
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
      { name: 'Type', value: 'Process'}
    ],
  }
  const result = await handle(start, msg, env)
  const msg2 = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Timestamp: "1000",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: 'print("hello world")'
  }
  const result2 = await handle(result.Memory, msg2, env)
  assert.ok(result2.Messages[0]?.Data)
  const msg3 = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Timestamp: "1000",
    Tags: [
      { name: 'Action', value: 'Info' }
    ],
  }
  const result3 = await handle(result2.Memory, msg3, env)
  assert.ok(result3.Messages[0]?.Data)
})
