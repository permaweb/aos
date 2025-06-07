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

test('run evaluate action unsuccessfully', async () => {
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
    Data: '100 < undefined'
  }
  const result = await handle(start, msg, env)

  assert.ok(result.Error.includes("attempt to compare number with nil"))
  assert.ok(true)
})

test('run evaluate action successfully', async () => {
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
    Data: '1 + 1'
  }
  const result = await handle(start, msg, env)
  assert.equal(result.Output?.data, '2')
  assert.ok(true)
})

test('print hello world', async () => {
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
    Data: `print("Hello World")`

  }
  const result = await handle(start, msg, env)
  assert.equal(result.Output?.data, "Hello World")
  assert.ok(true)
})


test('create an Assignment', async () => {
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
    Data: 'Assign({ Processes = { "pid-1", "pid-2" }, Message = "mid-1" })'
  }
  const result = await handle(start, msg, env)

  assert.deepStrictEqual(result.Assignments, [
    { Processes: ['pid-1', 'pid-2'], Message: 'mid-1' }
  ])
  assert.ok(true)
})