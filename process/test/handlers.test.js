import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }

test('handlers receive', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
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
local msg = ao.send({Target = ao.id, Data = "Hello"})
local res = Handlers.receive({From = msg.Target, ['X-Reference'] = msg.Ref_})
print('received msg')
return require('json').encode(res)
    `
  }

  // load handler
  const { Memory, Output, Messages } = await handle(null, msg, env)
  //console.log(Output)
  console.log(Messages[0])
  // ---
  const m = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [{
      name: 'X-Reference', value: '1'
    }],
    Data: 'test receive'
  }
  const result = await handle(Memory, m, env)
  console.log(result.Output)
  assert.ok(true)
})

test('resolvers', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
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
Handlers.once("onetime", 
  { 
     Action = "ping",
     Data = "ping"
  }, 
  function (Msg) 
    print("pong")
  end
)
    `
  }
  // load handler
  const { Memory } = await handle(null, msg, env)
  // ---
  const ping = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'Action', value: 'ping' }
    ],
    Data: 'ping'
  }
  const result = await handle(Memory, ping, env)
  // handled once
  assert.equal(result.Output.data, 'pong')
})

test('handlers once', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
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
Handlers.once("onetime", 
  Handlers.utils.hasMatchingData("ping"), 
  function (Msg) 
    print("pong")
  end
)
    `
  }
  // load handler
  const { Memory } = await handle(null, msg, env)
  // ---
  const ping = {
    From: 'FRED',
    Target: 'AOS',
    Owner: 'FRED',
    Tags: [],
    Data: 'ping'
  }
  const result = await handle(Memory, ping, env)
  // handled once
  assert.equal(result.Output.data, 'pong')

  const result2 = await handle(result.Memory, ping, env)
  // not handled
  assert.ok(result2.Output.data.includes('New Message From'))
})

test('ping pong', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
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
Handlers.add("ping", 
  Handlers.utils.hasMatchingData("ping"), 
  function (Msg) 
    print("pong")
  end
)
    `
  }
  // load handler
  const { Memory } = await handle(null, msg, env)
  // ---
  const ping = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [],
    Data: 'ping'
  }
  const result = await handle(Memory, ping, env)
  assert.equal(result.Output.data, 'pong')
  assert.ok(true)
})

test('handler pipeline', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
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
Handlers.add("one", 
  function (Msg)
    return "continue"
  end, 
  function (Msg) 
    print("one")
  end
)
Handlers.add("two", 
  function (Msg)
    return "continue"
  end, 
  function (Msg) 
    print("two")
  end
)

Handlers.add("three", 
  function (Msg)
    return "skip"
  end, 
  function (Msg) 
    print("three")
  end
)
    `
  }
  // load handler
  const { Memory } = await handle(null, msg, env)
  // ---
  const ping = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [],
    Data: 'ping'
  }
  const result = await handle(Memory, ping, env)
  assert.equal(result.Output.data, 'one\ntwo\n\x1B[90mNew Message From \x1B[32mFRE...RED\x1B[90m: \x1B[90mData = \x1B[34mping\x1B[0m')
  assert.ok(true)
})

test('timestamp', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
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
Handlers.add("timestamp", 
  Handlers.utils.hasMatchingData("timestamp"), 
  function (Msg) 
    print(os.time())
  end
)
    `
  }
  // load handler
  const { Memory } = await handle(null, msg, env)
  // ---
  const currentTimestamp = Date.now();
  const timestamp = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [],
    Data: 'timestamp',
    Timestamp: currentTimestamp
  }
  const result = await handle(Memory, timestamp, env)
  assert.equal(result.Output.data, currentTimestamp)
  assert.ok(true)
})

test('test pattern, fn handler', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
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
Handlers.add("Balance", 
  function (msg) 
    msg.reply({Data = "1000"})
  end
)
    `
  }
  // load handler
  const { Memory } = await handle(null, msg, env)
  // ---
  const currentTimestamp = Date.now();
  const balance = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [{ name: 'Action', value: 'Balance' }],
    Data: 'timestamp',
    Timestamp: currentTimestamp
  }
  const result = await handle(Memory, balance, env)
  assert.equal(result.Messages[0].Data, "1000")
  assert.ok(true)
})