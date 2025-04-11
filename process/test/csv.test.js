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

test('run csv encode and parse', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const msg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "AOS",
    Module: "WOOPAWOOPA",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: `
local csv = require('.ftcsv')
local data = csv.encode({
  { address = "addr1", amount = "10" },
  { address = "addr2", amount = "20" }
})
local result = csv.parse(data, { loadFromString = true})
print(require('json').encode(result))
    `
  }
  const result = await handle(start, msg, env)
  const data = JSON.parse(result.Output.data)

  assert.deepEqual(data, [{ amount: "10", address: "addr1"}, { amount: "20", address: "addr2"}])
})
