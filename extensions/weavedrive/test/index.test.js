const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const { test } = require('node:test')
const assert = require('assert')
const weaveDrive = require('../src/index.js')
const wasm = fs.readFileSync('./aosqlite.wasm')

let memory = null

const Module = {
  Id: "MODULE",
  Owner: "OWNER",
  Tags: [
    { name: 'Data-Protocol', value: 'ao'},
    { name: 'Variant', value: 'ao.TN.1'},
    { name: 'Type', value: 'Module'}
  ]
}

const Process = {
  Id: 'PROCESS',
  Owner: 'PROCESS',
  Tags: [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'Variant', value: 'ao.TN.1' },
    { name: 'Type', value: 'Process' },
    { name: 'Extension', value: 'WeaveDrive' }
  ]
}

const Msg = {
  Id: 'MESSAGE',
  Owner: 'MESSAGE',
  From: 'PROCESS',
  Module: 'MODULE',
  Tags: [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'Variant', value: 'ao.TN.1' },
    { name: 'Type', value: 'Message' },
    { name: 'Action', value: 'Eval' }
  ],
  "Block-Height": 1000,
  Timestamp: Date.now()
}

test('ok', async () => {
  const handle = await AoLoader(wasm, {
    format: 'wasm64-unknown-emscripten-draft_2024_02_15',
    WeaveDrive: weaveDrive,
    admissableList: [
      "dx3GrOQPV5Mwc1c-4HTsyq0s1TNugMf7XfIKJkyVQt8", // Random NFT metadata (1.7kb of JSON)
      "XOJ8FBxa6sGLwChnxhF2L71WkKLSKq1aU5Yn5WnFLrY", // GPT-2 117M model.
      "M-OzkyjxWhSvWYF87p0kvmkuAEEkvOzIj4nMNoSIydc", // GPT-2-XL 4-bit quantized model.
      "kd34P4974oqZf2Db-hFTUiCipsU6CzbR6t-iJoQhKIo", // Phi-2 
      "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo", // Phi-3 Mini 4k Instruct
      "sKqjvBbhqKvgzZT4ojP1FNvt4r_30cqjuIIQIr-3088", // CodeQwen 1.5 7B Chat q3
      "Pr2YVrxd7VwNdg6ekC0NXWNKXxJbfTlHhhlrKbAd1dA", // Llama3 8B Instruct q4
      "jbx-H6aq7b3BbNCHlK50Jz9L-6pz9qmldrYXMwjqQVI"  // Llama3 8B Instruct q8
    ],
    ARWEAVE: 'https://arweave.net',
    mode: "test",
    blockHeight: 1000,
    spawn: {
      "Scheduler": "TEST_SCHED_ADDR"
    },
    process: Process
  })
  const result = await handle(memory, {
    ...Msg,
    Data: `
local block = io.open('/block/1439783')
local transactions = require('json').decode(
  block:read(block:seek('end'))
).txs
block:close()


local results = {}

local file = io.open('/tx/' .. transactions[1], 'r')
if not file then
  return "File not found!"
end
local size = file:seek('end')
local content = file:read(size) 
file:close()
local data = require('json').decode(content)
return { Owner = data.owner, Target = data.target, Quantity = data.quantity } 

    `
  }, { Process, Module })
  console.log(result.Output.data.output)
  assert.ok(true)
})

