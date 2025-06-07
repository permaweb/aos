const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const { describe, test } = require('node:test')
const assert = require('assert')
const weaveDrive = require('../src/index.js')
const wasm = fs.readFileSync('./process.wasm')
const bootLoaderWasm = fs.readFileSync('./bootloader.wasm')

let memory = null

const Module = {
  Id: 'MODULE',
  Owner: 'OWNER',
  Tags: [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'Variant', value: 'ao.TN.1' },
    { name: 'Type', value: 'Module' },
    { name: 'Authority', value: 'PROCESS' }
  ]
}

const Process = {
  Id: 'PROCESS',
  Owner: 'PROCESS',
  Tags: [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'Variant', value: 'ao.TN.1' },
    { name: 'Type', value: 'Process' },
    { name: 'Extension', value: 'WeaveDrive' },
    { name: 'Module', value: 'MODULE' },
    { name: 'Authority', value: 'PROCESS' }
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
  'Block-Height': 1000,
  Timestamp: Date.now()
}

const options = {
  format: 'wasm64-unknown-emscripten-draft_2024_02_15',
  WeaveDrive: weaveDrive,
  ARWEAVE: 'https://arweave.net',
  mode: 'test',
  blockHeight: 1000,
  spawn: {
    tags: Process.Tags
  },
  module: {
    tags: Module.Tags
  }
}

const drive = fs.readFileSync('./client/main.lua', 'utf-8')

test('load client source', async () => {
  const handle = await AoLoader(wasm, options)
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
  assert.equal(result.Output.data, '63')
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
  assert.ok(true)
})

test('read twice', async function () {
  const handle = await AoLoader(wasm, options)
  const result = await handle(memory, {
    ...Msg,
    Data: `
local drive = require('WeaveDrive')
function getTxs()
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
local results = getTxs() 
local results2 = getTxs()
return require('json').encode({ A = #results, B = #results2 }) 
    `
  }, { Process, Module })
  memory = result.Memory
  const res = JSON.parse(result.Output.data)

  assert.equal(res.A, res.B)
})

describe('Assignments mode', () => {
  const TX_ID_TO_LOAD = 'iaiAqmcYrviugZq9biUZKJIAi_zIT_mgFHAWZzMvDuk'
  const blockHeight = 1536315
  const mode = 'Assignments'

  const ProcessAssignmentsMode = {
    Id: 'PROCESS',
    Owner: 'PROCESS',
    Target: 'PROCESS',
    Tags: [
      { name: 'Data-Protocol', value: 'ao' },
      { name: 'Variant', value: 'ao.TN.1' },
      { name: 'Type', value: 'Process' },
      { name: 'Extension', value: 'WeaveDrive' },
      { name: 'Module', value: 'MODULE' },
      { name: 'Authority', value: 'PROCESS' },
      { name: 'Availability-Type', value: mode }
    ],
    Data: 'Test = 1',
    From: 'PROCESS',
    Module: 'MODULE',
    'Block-Height': 4567,
    Timestamp: Date.now()
  }

  test('read tx attested by Scheduler', async () => {
    const ProcessSchedulerAttested = {
      ...ProcessAssignmentsMode,
      Tags: [
        ...ProcessAssignmentsMode.Tags,
        { name: 'Scheduler', value: 'kdUCABg56Jroco1kMwfF-YIjah9wBbZ1BhyOnwLwOY0' }
      ]
    }

    const handle = await AoLoader(wasm, {
      ...options,
      spawn: {
        id: ProcessSchedulerAttested.Id,
        owner: ProcessSchedulerAttested.Owner,
        tags: ProcessSchedulerAttested.Tags
      },
      mode
    })
    const result = await handle(null, {
      ...Msg,
      'Block-Height': blockHeight + 2,
      Data: `
        local function _load() ${drive} end
        _G.package.loaded['WeaveDrive'] = _load()
        local drive = require('WeaveDrive')
        return drive.getData("${TX_ID_TO_LOAD}")
      `
    }, { Process: ProcessSchedulerAttested, Module })

    assert.equal(result.Output.data, 'hello from attested')
  })

  test('read tx attested by Attestor', async () => {
    const ProcessAttestorAttested = {
      ...ProcessAssignmentsMode,
      Tags: [
        ...ProcessAssignmentsMode.Tags,
        { name: 'Scheduler', value: 'something-else' },
        { name: 'Attestor', value: 'kdUCABg56Jroco1kMwfF-YIjah9wBbZ1BhyOnwLwOY0' }
      ]
    }

    const handle = await AoLoader(wasm, {
      ...options,
      spawn: {
        id: ProcessAttestorAttested.Id,
        owner: ProcessAttestorAttested.Owner,
        tags: ProcessAttestorAttested.Tags
      },
      mode
    })
    const result = await handle(null, {
      ...Msg,
      'Block-Height': blockHeight + 2,
      Data: `
        local function _load() ${drive} end
        _G.package.loaded['WeaveDrive'] = _load()
        local drive = require('WeaveDrive')
        return drive.getData("${TX_ID_TO_LOAD}")
      `
    }, { Process: ProcessAttestorAttested, Module })

    assert.equal(result.Output.data, 'hello from attested')
  })
})

describe('Individual Mode', () => {
  const TX_ID_TO_LOAD = 'msEHJnwpmxR0RP-YqeCk91l_x8O9QNOP8RZYG_1prYE'
  const blockHeight = 1536315
  const mode = 'Individual'

  const ProcessIndividualMode = {
    Id: 'PROCESS',
    Owner: 'PROCESS',
    Target: 'PROCESS',
    Tags: [
      { name: 'Data-Protocol', value: 'ao' },
      { name: 'Variant', value: 'ao.TN.1' },
      { name: 'Type', value: 'Process' },
      { name: 'Extension', value: 'WeaveDrive' },
      { name: 'Module', value: 'MODULE' },
      { name: 'Authority', value: 'PROCESS' },
      { name: 'Availability-Type', value: mode }
    ],
    Data: 'Test = 1',
    From: 'PROCESS',
    Module: 'MODULE',
    'Block-Height': 4567,
    Timestamp: Date.now()
  }

  test('read tx attested by Scheduler', async () => {
    const ProcessSchedulerAttested = {
      ...ProcessIndividualMode,
      Tags: [
        ...ProcessIndividualMode.Tags,
        { name: 'Scheduler', value: 'kdUCABg56Jroco1kMwfF-YIjah9wBbZ1BhyOnwLwOY0' }
      ]
    }

    const handle = await AoLoader(wasm, {
      ...options,
      spawn: {
        id: ProcessSchedulerAttested.Id,
        owner: ProcessSchedulerAttested.Owner,
        tags: ProcessSchedulerAttested.Tags
      },
      mode
    })
    const result = await handle(null, {
      ...Msg,
      'Block-Height': blockHeight + 2,
      Data: `
        local function _load() ${drive} end
        _G.package.loaded['WeaveDrive'] = _load()
        local drive = require('WeaveDrive')
        return drive.getData("${TX_ID_TO_LOAD}")
      `
    }, { Process: ProcessSchedulerAttested, Module })

    assert.equal(result.Output.data, '1234')
  })
})

// test weavedrive feature of accepting multiple gateways
describe('multi-url', () => {
  const urls = 'https://arweave.net/does-not-exist,https://g8way.io'
  test('read block', async () => {
    const handle = await AoLoader(wasm, {
      ...options,
      ARWEAVE: urls
    })
    const result = await handle(memory, {
      ...Msg,
      Data: `
        return #require('WeaveDrive').getBlock('1439784').txs
      `
    }, { Process, Module })
    memory = result.Memory
    assert.equal(result.Output.data, '20')
  })

  test('read tx', async () => {
    const handle = await AoLoader(wasm, {
      ...options,
      ARWEAVE: urls
    })
    const result = await handle(memory, {
      ...Msg,
      Data: `
        local results = {}
        local drive = require('WeaveDrive')
        local txs = drive.getBlock('1439784').txs
        for i=1,#txs do
          local tx = drive.getTx(txs[i])
        end
        return results
      `
    }, { Process, Module })
    memory = result.Memory
    assert.ok(true)
  })
})

test('boot loader set to Data', async function () {
  /**
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
  print("Test " .. Test)
      `,
    From: 'PROCESS',
    Module: 'MODULE',
    'Block-Height': 1234,
    Timestamp: Date.now()
  }

  const optionsBootLoaderData = { ...options, mode: null }

  const handle = await AoLoader(bootLoaderWasm, optionsBootLoaderData)
  const result = await handle(null, {
    ...ProcessBootLoaderData
  }, { Process: ProcessBootLoaderData, Module })
  assert.equal(result.Output.data, 'Test 1')
})

test('boot loader set to tx id', async function () {
  const BootLoadedFromTx = 'Fmtgzy1Chs-5ZuUwHpQjQrQ7H7v1fjsP0Bi8jVaDIKA'
  const ProcessBootLoaderTx = {
    Id: 'PROCESS',
    Owner: 'PROCESS',
    Target: 'PROCESS',
    Tags: [
      { name: 'Data-Protocol', value: 'ao' },
      { name: 'Variant', value: 'ao.TN.1' },
      { name: 'Type', value: 'Process' },
      { name: 'Extension', value: 'WeaveDrive' },
      { name: 'On-Boot', value: BootLoadedFromTx },
      { name: 'Module', value: 'MODULE' },
      { name: 'Authority', value: 'PROCESS' }
    ],
    Data: `
  Test = 1
      `,
    From: 'PROCESS',
    Module: 'MODULE',
    'Block-Height': 4567,
    Timestamp: Date.now()
  }

  const optionsBootLoaderTx = {
    ...options,
    spawn: {
      id: ProcessBootLoaderTx.Id,
      owner: ProcessBootLoaderTx.Owner,
      tags: ProcessBootLoaderTx.Tags
    },
    mode: null
  }

  const handle = await AoLoader(bootLoaderWasm, optionsBootLoaderTx)
  const { Memory } = await handle(null, {
    ...ProcessBootLoaderTx
  }, { Process: ProcessBootLoaderTx, Module })

  /**
   * Now access a value set by the On-Boot tx's
   * evaluation
   */
  const result = await handle(Memory, {
    ...Msg,
    Owner: 'PROCESS',
    Target: 'PROCESS',
    From: 'PROCESS',
    Data: 'Ticker'
  }, { Process: ProcessBootLoaderTx, Module })

  assert.equal(result.Output.data, '<TICKER>')
})

describe('joinUrl', () => {
  const wd = weaveDrive()
  const joinUrl = wd.joinUrl.bind(wd)

  test('should return the url', () => {
    assert.equal(joinUrl({ url: 'https://arweave.net/graphql' }), 'https://arweave.net/graphql')
    assert.equal(joinUrl({ url: 'https://arweave.net/graphql?foo=bar' }), 'https://arweave.net/graphql?foo=bar')
    assert.equal(joinUrl({ url: 'https://arweave.net/graphql', path: undefined }), 'https://arweave.net/graphql')
  })

  test('should append the path', () => {
    assert.equal(joinUrl({ url: 'https://arweave.net', path: 'graphql' }), 'https://arweave.net/graphql')
    assert.equal(joinUrl({ url: 'https://arweave.net', path: '/graphql' }), 'https://arweave.net/graphql')
    assert.equal(joinUrl({ url: 'https://arweave.net/', path: 'graphql' }), 'https://arweave.net/graphql')
    assert.equal(joinUrl({ url: 'https://arweave.net/', path: '/graphql' }), 'https://arweave.net/graphql')

    assert.equal(joinUrl({ url: 'https://arweave.net?foo=bar', path: 'graphql' }), 'https://arweave.net/graphql?foo=bar')
    assert.equal(joinUrl({ url: 'https://arweave.net?foo=bar', path: '/graphql' }), 'https://arweave.net/graphql?foo=bar')
    assert.equal(joinUrl({ url: 'https://arweave.net/?foo=bar', path: 'graphql' }), 'https://arweave.net/graphql?foo=bar')
    assert.equal(joinUrl({ url: 'https://arweave.net/?foo=bar', path: '/graphql' }), 'https://arweave.net/graphql?foo=bar')
  })
})
