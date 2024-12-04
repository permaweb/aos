import { describe, test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')

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
    { name: 'Module', value: 'MODULE' },
    { name: 'Authority', value: 'PROCESS' }
  ]
}

const options = {
  format: 'wasm64-unknown-emscripten-draft_2024_02_15',
  mode: 'test',
  blockHeight: 1000,
  spawn: {
    tags: Process.Tags
  },
  module: {
    tags: Module.Tags
  }
}

describe('timeout', () => {
  test('Create handler with timeout, onTimeout handle', async () => {
    const handle = await AoLoader(wasm, options)
    const env = {
      Process: {
        Id: 'AOS',
        Owner: 'FOOBAR',
        Tags: []
      }
    }
    const msg = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' }
      ],
      Timestamp: 1000,
      Data: `
        local json = require('json')
        Handlers.add(
          'test-timeout',
          Handlers.utils.hasMatchingTag('Action', 'Timeout'),
          function (msg)
            print('Timeout handler triggered')
            print(msg.Data)
          end,
          5,
          { timeout = '10-seconds', onTimeout = 'handle', timeoutPayload = { Data = 'this should print'} }
        )
        return json.encode(Handlers.list)
      `
    }

    const { Output } = await handle(null, msg, env)

    const handlers = JSON.parse(Output.data)
    const handler = handlers.find(h => h.name === 'test-timeout')
    const timeout = handler.timeout

    assert.equal(handler.name, 'test-timeout')
    assert.equal(handler.maxRuns, 5)
    assert.equal(timeout.timeout, '10-seconds')
    assert.equal(timeout.milliseconds, 10000)
    assert.equal(timeout.onTimeout, 'handle')
    assert.equal(timeout.start, 1000)
    assert.equal(timeout.timeoutPayload.Data, 'this should print')
  })

  test('Create handler with timeout, onTimeout is function', async () => {
    const handle = await AoLoader(wasm, options)
    const env = {
      Process: {
        Id: 'AOS',
        Owner: 'FOOBAR',
        Tags: []
      }
    }
    const msg = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
      Timestamp: 1000,
      Tags: [
        { name: 'Action', value: 'Eval' }
      ],
      Data: `
        local json = require('json')
        Handlers.add(
          'test-timeout',
          Handlers.utils.hasMatchingTag('Action', 'Timeout'),
          function (msg)
            print('Timeout handler triggered')
            print(msg.Data)
          end,
          5,
          { timeout = '10-seconds', onTimeout = function () print('Timeout handler triggered') end, timeoutPayload = { Data = 'this should print'} }
        )
        local createdHandler = Handlers.list[#Handlers.list]
        return json.encode({ createdHandler = createdHandler, onTimeoutType = type(createdHandler.timeout.onTimeout) })
      `
    }
    const { Output } = await handle(null, msg, env)
    const data = JSON.parse(Output.data)
    const handler = data.createdHandler
    const onTimeoutType = data.onTimeoutType
    assert.equal(onTimeoutType, 'function')
    assert.equal(handler.name, 'test-timeout')
    assert.equal(handler.maxRuns, 5)
    assert.equal(handler.timeout.timeout, '10-seconds')
    assert.equal(handler.timeout.milliseconds, 10000)
    assert.equal(handler.timeout.start, 1000)
    assert.equal(handler.timeout.timeoutPayload.Data, 'this should print')
  })

  test('Create handler with timeout, onTimeout is handle, triggered before timeout', async () => {
    const handle = await AoLoader(wasm, options)
    const env = {
      Process: {
        Id: 'AOS',
        Owner: 'FOOBAR',
        Tags: []
      }
    }

    // 1. Create handler
    const msg1 = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' }
      ],
      Timestamp: 1000,
      Data: `
        local json = require('json')
        Handlers.add(
          'test-timeout',
          Handlers.utils.hasMatchingTag('Action', 'Timeout'),
          function (msg)
            print('Timeout handler triggered')
          end,
          5,
          { timeout = '10-seconds', onTimeout = 'handle', timeoutPayload = { Data = 'this should print'} }
        )
      `
    }
    const { Memory } = await handle(null, msg1, env)
    // 2. Trigger timeout handler
    const msg2 = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
      Timestamp: 1001,
      Tags: [
        { name: 'Action', value: 'Timeout' }
      ]
    }
    const { Output, Memory: Memory2 } = await handle(Memory, msg2, env)
    assert.equal(Output.data, 'Timeout handler triggered') // This is the result of the timeout handler being triggered
    // 3. Check that handler was triggered
    const msg3 = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' }
      ],
      Timestamp: 1002,
      Data: `
        return require('json').encode(Handlers.list)
      `
    }
    const { Output: Output3 } = await handle(Memory2, msg3, env)
    const data = JSON.parse(Output3.data)
    const handler = data.find(h => h.name === 'test-timeout')
    assert.equal(handler.name, 'test-timeout')
    assert.equal(handler.maxRuns, 4) // 1 run was triggered, so maxRuns should be 4
  })

  test('Create handler with timeout, onTimeout is handle, times out', async () => {
    const handle = await AoLoader(wasm, options)
    const env = {
      Process: {
        Id: 'AOS',
        Owner: 'FOOBAR',
        Tags: []
      }
    }

    // 1. Create handler
    const msg1 = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' }
      ],
      Timestamp: 1000,
      Data: `
        local json = require('json')
        Handlers.add(
          'test-timeout',
          Handlers.utils.hasMatchingTag('Action', 'Timeout'),
          function (msg)
            print(msg.Data)
          end,
          5,
          { timeout = '1-seconds', onTimeout = 'handle', timeoutPayload = { Data = 'this should print'} }
        )
      `
    }
    const { Memory } = await handle(null, msg1, env)
    // 2. Trigger timeout handler
    const msg2 = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
      Timestamp: 1001,
      Tags: [
        { name: 'Action', value: 'Timeout' }
      ],
      Data: 'Test Message Data'
    }
    const { Output, Memory: Memory2 } = await handle(Memory, msg2, env)
    assert.equal(Output.data, 'Test Message Data') // This is the result of the timeout handler being triggered (the message Data)
    // 3. Check that handler was triggered
    const msg3 = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
      Timestamp: 1002,
      Tags: [
        { name: 'Action', value: 'Eval' }
      ],
      Data: `
        return require('json').encode(Handlers.list)
      `
    }
    const { Memory: Memory3 } = await handle(Memory2, msg3, env)
    const msg4 = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
      Timestamp: 2002, // >1 second after timeout
      Tags: [
        { name: 'Action', value: 'Any' }
      ]
    }
    const { Memory: Memory4 } = await handle(Memory3, msg4, env)
    // 5. Check that handler was removed
    const msg5 = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
      Timestamp: 2003, // >1 second after timeout
      Tags: [
        { name: 'Action', value: 'Eval' }
      ],
      Data: `
        return require('json').encode(Handlers.list)
      `
    }
    const { Output: Output5 } = await handle(Memory4, msg5, env)

    const handlers = JSON.parse(Output5.data)
    const handler = handlers.findIndex(h => h.name === 'test-timeout')
    assert.equal(handler, -1)
  })
})

describe('receive', () => {
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
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
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
    const { Memory, Messages } = await handle(null, msg, env)
    // console.log(Output)
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
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
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
})

describe('once', () => {
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
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      Module: 'WOOPAWOOPA',
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
    'Block-Height': '1000',
    Id: '1234xyxfoo',
    Module: 'WOOPAWOOPA',
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
    'Block-Height': '1000',
    Id: '1234xyxfoo',
    Module: 'WOOPAWOOPA',
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
    'Block-Height': '1000',
    Id: '1234xyxfoo',
    Module: 'WOOPAWOOPA',
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
  const currentTimestamp = Date.now()
  const timestamp = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [],
    Data: 'timestamp',
    Timestamp: currentTimestamp
  }
  const result = await handle(Memory, timestamp, env)
  assert.equal(result.Output.data, '\x1B[32m' + currentTimestamp + '\x1B[0m')
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
    'Block-Height': '1000',
    Id: '1234xyxfoo',
    Module: 'WOOPAWOOPA',
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
  const currentTimestamp = Date.now()
  const balance = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [{ name: 'Action', value: 'Balance' }],
    Data: 'timestamp',
    Timestamp: currentTimestamp
  }
  const result = await handle(Memory, balance, env)
  assert.equal(result.Messages[0].Data, '1000')
  assert.ok(true)
})
