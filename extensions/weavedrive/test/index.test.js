const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const { test } = require('node:test')
const assert = require('assert')
const weaveDrive = require('../src/index.js')
const wasm = fs.readFileSync('./aosqlite.wasm')
const bootLoaderWasm = fs.readFileSync('./bootloader.wasm')

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

const options = {
    format: 'wasm64-unknown-emscripten-draft_2024_02_15',
    WeaveDrive: weaveDrive,
    ARWEAVE: 'https://arweave.net',
    mode: "test",
    blockHeight: 1000,
    spawn: {
      "Scheduler": "TEST_SCHED_ADDR"
    },
    process: Process
}

test('load client source', async () => {
  const handle = await AoLoader(wasm, options)
  const drive = fs.readFileSync('./client/main.lua', 'utf-8')
  const result = await handle(memory, {
    ...Msg,
    Data: `
local function _load()
  ${drive}
end
_G.package.loaded['WeaveDrive'] = _load()
return "ok"
`
  }, { Process, Module })
  memory = result.Memory
  assert.ok(true)
})

test('read block', async () => {
  const handle = await AoLoader(wasm, options)
  const result = await handle(memory, {
    ...Msg,
    Data: `
    return #require('WeaveDrive').getBlock('1439783').txs
`
  }, { Process, Module })
  memory = result.Memory
  console.log(result.Output.data.output)
  assert.equal(result.Output.data.output, '63')
})


test('read tx', async () => {
  const handle = await AoLoader(wasm, options)
  const result = await handle(memory, {
    ...Msg,
    Data: `
local results = {}
local drive = require('WeaveDrive')
local txs = drive 
  .getBlock('1439783').txs
for i=1,#txs do
  local tx = drive.getTx(txs[i])
  table.insert(results, {
    Owner = tx.ownerAddress,
    Target = tx.target,
    Quantity = tx.quantity
  })
end

return results
    `
  }, { Process, Module })
  memory = result.Memory
  console.log(result.Output.data.output)
  assert.ok(true)
})

test('read twice', async function () {
  const handle = await AoLoader(wasm, options)
  const result = await handle(memory, {
    ...Msg,
    Data: `
local drive = require('WeaveDrive')
function getTxs(txs)
  local results = {}
  local txs = drive 
    .getBlock('1439783').txs
  for i=1,#txs do
    local tx, err = drive.getTx(txs[i])
    if not err then
      table.insert(results, {
        Owner = tx.ownerAddress,
        Target = tx.target,
        Quantity = tx.quantity
      })
    end
  end
  return results
end
local block = drive.getBlock('1439782')
local results = getTxs(block.txs) 
local results2 = getTxs(block.txs)

return require('json').encode({ A = #results, B = #results2 }) 
    `
  }, { Process, Module })
  memory = result.Memory
  const res = JSON.parse(result.Output.data.output)

  assert.equal(res.A, res.B)
})

let memoryBootLoader = null

 /*
  * The Process is also the first message when aop 6 boot loader
  * is enabled in the network
  */
const ProcessBootLoaderData = {
  Id: 'PROCESS',
  Owner: 'PROCESS',
  Target: 'PROCESS',
  Tags: [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'Variant', value: 'ao.TN.1' },
    { name: 'Type', value: 'Process' },
    { name: 'Extension', value: 'WeaveDrive' },
    { name: 'On-Boot', value: 'Data' },
    { name: 'Module', value: 'MODULE' },
    { name: 'Authority', value: 'PROCESS' }
  ],
  Data: `
Test = 1
    `,
  From: 'PROCESS',
  Module: 'MODULE',
  "Block-Height": 1000,
  Timestamp: Date.now()
}

const optionsBootLoaderData = { ...options, Process: ProcessBootLoaderData, mode: null}

test('boot loader set to Data', async function () {
  const handle = await AoLoader(bootLoaderWasm, optionsBootLoaderData)
  await handle(memoryBootLoader, {
    ...ProcessBootLoaderData
  }, { Process: ProcessBootLoaderData, Module })
})

const ProcessBootLoaderTx = {
  Id: 'PROCESS',
  Owner: 'PROCESS',
  Target: 'PROCESS',
  Tags: [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'Variant', value: 'ao.TN.1' },
    { name: 'Type', value: 'Process' },
    { name: 'Extension', value: 'WeaveDrive' },
    { name: 'On-Boot', value: 'Fmtgzy1Chs-5ZuUwHpQjQrQ7H7v1fjsP0Bi8jVaDIKA' },
    { name: 'Module', value: 'MODULE' },
    { name: 'Authority', value: 'PROCESS' }
  ],
  Data: `
Test = 1
    `,
  From: 'PROCESS',
  Module: 'MODULE',
  "Block-Height": 1000,
  Timestamp: Date.now()
}

const optionsBootLoaderTx = { ...options, Process: ProcessBootLoaderTx, mode: null}

test('boot loader set to tx id', async function () {
  const handle = await AoLoader(bootLoaderWasm, optionsBootLoaderTx)
  await handle(memoryBootLoader, {
    ...ProcessBootLoaderTx
  }, { Process: ProcessBootLoaderTx, Module })
})