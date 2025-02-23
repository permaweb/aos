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
      { name: "Scheduler", value: "1234?hint=https://localhost:10000"}
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
      { name: "Scheduler", value: "1234?hint=https://localhost:10000"}
    ]
  }, env)
  return Memory
}

test('send hint on scheduler it should pass with every message', async () => {
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
    Data: `
    Send({Target = ao.id, Data = "Hello"})
    print(ao.env.Process.Scheduler)
    `
  }
  const result = await handle(start, msg, env)
  console.log(result.Output.data)
  assert.equal(result.Messages[0].Tags.find(t => t.name === "From-Scheduler").value, "1234?hint=https://localhost:10000")
 
})

