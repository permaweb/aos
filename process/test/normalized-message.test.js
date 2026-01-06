import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: 'wasm64-unknown-emscripten-draft_2024_02_15' }

const env = {
  Process: {
    Id: 'AOS',
    Owner: 'FOOBAR',
    Tags: [{ name: 'Name', value: 'Thomas' }]
  }
}

async function init(handle) {
  const { Memory } = await handle(
    null,
    {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '999',
      Id: 'AOS',
      Module: 'WOOPAWOOPA',
      Tags: [{ name: 'Name', value: 'Thomas' }]
    },
    env
  )
  return Memory
}

test('message normalization - to title case', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)

  // Create an evaluation message that will inspect an incoming message
  const evalMsg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    ['Block-Height']: '1000',
    Id: '1234xyxfoo',
    Module: 'WOOPAWOOPA',
    Tags: [{ name: 'Action', value: 'Eval' }],
    Data: `
Handlers.add("inspect-normalized", 
  function (msg)
    return msg.Tags["type"] == "test-event" or msg.Tags["Type"] == "test-event"
  end, 
  function (msg) 
    -- Print normalized message keys
    print("Type: " .. (msg.Tags["Type"] or "nil"))
    print("Data-Protocol: " .. (msg.Tags["Data-Protocol"] or "nil"))
    print("Message: " .. (msg.Tags["Message"] or "nil"))
    print("Action: " .. (msg.Tags["Action"] or "nil"))
    
    -- Return true if keys were normalized properly
    return msg.Tags["Type"] == "test-event" and 
           msg.Tags["Data-Protocol"] == "https://example.com/protocol" and
           msg.Tags["Message"] == "Hello, world!"
  end
)
    `
  }

  // Load the handler
  const { Memory } = await handle(start, evalMsg, env)

  // Test message with lowercase keys
  const testMsg = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'type', value: 'test-event' },
      { name: 'data-PROTOCOL', value: 'https://example.com/protocol' },
      { name: 'MESSAGE', value: 'Hello, world!' },
      { name: 'action', value: 'test-action' }
    ],
    Data: 'Test normalized message'
  }

  const { Output } = await handle(Memory, testMsg, env)

  // Check if output contains the normalized values
  assert.ok(Output.data.includes('Type: test-event'))
  assert.ok(Output.data.includes('Data-Protocol: https://example.com/protocol'))
  assert.ok(Output.data.includes('Message: Hello, world!'))
  assert.ok(Output.data.includes('Action: test-action'))
})
