import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }

const env = {
  Process: {
    Id: 'AOS',
    Owner: '11234',
    Tags: [
      { name: 'Name', value: 'Thomas' },
      { name: "Authority", value: "11234"}
    ]
  },
  Module: {
    Id: 'WOOPAWOOPA'
  }
}

async function init(handle) {
  const {Memory} = await handle(null, {
    Target: 'AOS',
    From: '11234',
    Owner: '11234',
    'Block-Height': '999',
    Id: 'AOS',
    Module: 'WOOPAWOOPA',
    Tags: [
      { name: 'Name', value: 'Thomas' },
      { name: "Authority", value: "11234"}
    ]
  }, env)
  return Memory
}

test('send hint on from process', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const msg = {
    Target: 'AOS',
    From: '11234',
    Owner: '11234',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' },
      { name: 'From-Process', value: '11234&hint=http://localhost:10000&hint-ttl=3600000'}
    ],
    Data: `
    Send({Target = "11234", Data = "Hello"})
    `
  }
  const result = await handle(start, msg, env)
  
  assert.equal(result.Messages[0].Target, "11234&hint=http://localhost:10000&hint-ttl=3600000")
  //assert.equal(result.Messages[0].Tags.find(t => t.name === "Target").value, "1234?hint=https://localhost:10000")
 
})

