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

test('case-insensitive action matching', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler that matches Action = "test-action"
  const setupMsg = {
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
Handlers.add("test-action-handler", 
  { Action = "test-action" },
  function(msg)
    print("Handler matched: Action = " .. (msg.Action or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test message with lowercase action
  const testMsg = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'action', value: 'test-action' }
    ],
    Data: 'test message'
  }
  
  const result = await handle(Memory, testMsg, env)
  assert.ok(result.Output.data.includes('Handler matched: Action = test-action'))
})

test('case-insensitive data-protocol matching', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler that matches Data-Protocol = "test-protocol"
  const setupMsg = {
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
Handlers.add("test-protocol-handler",
  { ["Data-Protocol"] = "test-protocol" },
  function(msg)
    print("Handler matched: Data-Protocol = " .. (msg.Tags["Data-Protocol"] or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test message with different case protocol
  const testMsg = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'data-protocol', value: 'test-protocol' }
    ],
    Data: 'test message'
  }
  
  const result = await handle(Memory, testMsg, env)
  assert.ok(result.Output.data.includes('Handler matched: Data-Protocol = test-protocol'))
})

test('case-insensitive content-type matching', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler that matches Content-Type = "application/json"
  const setupMsg = {
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
Handlers.add("test-content-type-handler",
  { ["Content-Type"] = "application/json" },
  function(msg)
    print("Handler matched: Content-Type = " .. (msg.Tags["Content-Type"] or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test message with different case content-type
  const testMsg = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'content-type', value: 'application/json' }
    ],
    Data: '{"test": "data"}'
  }
  
  const result = await handle(Memory, testMsg, env)
  assert.ok(result.Output.data.includes('Handler matched: Content-Type = application/json'))
})

test('comprehensive case variations - ACTION, action, Action', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler that matches Action = "test-action"
  const setupMsg = {
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
Handlers.add("case-variation-handler", 
  { Action = "test-action" },
  function(msg)
    print("Handler matched with Action: " .. (msg.Action or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test 1: lowercase "action"
  const testMsg1 = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'action', value: 'test-action' }
    ],
    Data: 'test message 1'
  }
  
  const result1 = await handle(Memory, testMsg1, env)
  assert.ok(result1.Output.data.includes('Handler matched with Action: test-action'))
  
  // Test 2: uppercase "ACTION"
  const testMsg2 = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'ACTION', value: 'test-action' }
    ],
    Data: 'test message 2'
  }
  
  const result2 = await handle(result1.Memory, testMsg2, env)
  assert.ok(result2.Output.data.includes('Handler matched with Action: test-action'))
  
  // Test 3: title case "Action" (should also work)
  const testMsg3 = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'Action', value: 'test-action' }
    ],
    Data: 'test message 3'
  }
  
  const result3 = await handle(result2.Memory, testMsg3, env)
  assert.ok(result3.Output.data.includes('Handler matched with Action: test-action'))
  
  // Test 4: mixed case "AcTiOn"
  const testMsg4 = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'AcTiOn', value: 'test-action' }
    ],
    Data: 'test message 4'
  }
  
  const result4 = await handle(result3.Memory, testMsg4, env)
  assert.ok(result4.Output.data.includes('Handler matched with Action: test-action'))
})

test('comprehensive protocol case variations', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler that matches Data-Protocol
  const setupMsg = {
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
Handlers.add("protocol-case-handler", 
  { ["Data-Protocol"] = "test-protocol" },
  function(msg)
    print("Protocol handler matched: " .. (msg.Tags["Data-Protocol"] or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test various case patterns for Data-Protocol (including underscores)
  const testCases = [
    'data-protocol',
    'DATA-PROTOCOL', 
    'Data-Protocol',
    'data_protocol',      // underscore should convert to dash
    'DATA_PROTOCOL',      // underscore should convert to dash
    'Data_Protocol',      // underscore should convert to dash
    'data_PROTOCOL',      // mixed case with underscore
    'DATA-protocol'       // mixed case with dash
  ]
  
  let currentMemory = Memory
  
  for (let i = 0; i < testCases.length; i++) {
    const testMsg = {
      Target: 'AOS',
      From: 'FRED',
      Owner: 'FRED',
      Tags: [
        { name: testCases[i], value: 'test-protocol' }
      ],
      Data: `test message ${i + 1}`
    }
    
    const result = await handle(currentMemory, testMsg, env)
    assert.ok(result.Output.data.includes('Protocol handler matched: test-protocol'), 
      `Failed for case variation: ${testCases[i]}`)
    currentMemory = result.Memory
  }
})

test('multiple case-insensitive keys in single handler', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler that matches multiple keys with different cases
  const setupMsg = {
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
Handlers.add("multi-key-handler",
  { 
    Action = "migrate",
    ["Content-Type"] = "application/json"
  },
  function(msg)
    print("Migration handler triggered!")
    print("Action: " .. (msg.Action or "nil"))
    print("Content-Type: " .. (msg.Tags["Content-Type"] or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Send message with various case patterns (simulating legacy vs mainnet differences)
  const migrationMsg = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'action', value: 'migrate' },
      { name: 'content-type', value: 'application/json' }
    ],
    Data: '{"migration": "test"}'
  }
  
  const result = await handle(Memory, migrationMsg, env)
  
  // Verify the handler was triggered and normalization worked
  assert.ok(result.Output.data.includes('Migration handler triggered!'))
  assert.ok(result.Output.data.includes('Action: migrate'))
  assert.ok(result.Output.data.includes('Content-Type: application/json'))
})

test('backward compatibility - exact key matches still work', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler with exact case matching
  const setupMsg = {
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
Handlers.add("exact-match-handler",
  { Action = "test-action" },
  function(msg)
    print("Exact match handler triggered: " .. (msg.Action or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test message with exact case match
  const testMsg = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'Action', value: 'test-action' }
    ],
    Data: 'test message'
  }
  
  const result = await handle(Memory, testMsg, env)
  assert.ok(result.Output.data.includes('Exact match handler triggered: test-action'))
})

test('mixed case keys with underscores and dashes', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler that matches normalized keys
  const setupMsg = {
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
Handlers.add("mixed-case-handler",
  { 
    ["X-Reference"] = "test-ref"
  },
  function(msg)
    print("Mixed case handler triggered!")
    print("X-Reference: " .. (msg.Tags["X-Reference"] or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test message with various case patterns
  const testMsg = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'x-reference', value: 'test-ref' }
    ],
    Data: 'test message'
  }
  
  const result = await handle(Memory, testMsg, env)
  
  assert.ok(result.Output.data.includes('Mixed case handler triggered!'))
  assert.ok(result.Output.data.includes('X-Reference: test-ref'))
})

test('handler should not match when values differ', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler that should NOT match
  const setupMsg = {
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
Handlers.add("no-match-handler",
  { Action = "expected-action" },
  function(msg)
    print("This handler should NOT be triggered!")
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test message with different action value
  const testMsg = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'action', value: 'different-action' }
    ],
    Data: 'test message'
  }
  
  const result = await handle(Memory, testMsg, env)
  // Should show default inbox message, not our handler
  assert.ok(result.Output.data.includes('New Message From'))
  assert.ok(!result.Output.data.includes('This handler should NOT be triggered!'))
})

test('underscore to dash conversion', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler that expects dashes
  const setupMsg = {
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
Handlers.add("underscore-dash-handler", 
  { 
    ["Data-Protocol"] = "test-protocol",
    ["Content-Type"] = "application/json",
    ["Reply-To"] = "test-reply"
  },
  function(msg)
    print("Underscore conversion handler triggered!")
    print("Data-Protocol: " .. (msg.Tags["Data-Protocol"] or "nil"))
    print("Content-Type: " .. (msg.Tags["Content-Type"] or "nil"))
    print("Reply-To: " .. (msg.Tags["Reply-To"] or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test message with underscores that should be converted to dashes
  const testMsg = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'data_protocol', value: 'test-protocol' },
      { name: 'content_type', value: 'application/json' },
      { name: 'reply_to', value: 'test-reply' }
    ],
    Data: '{"test": "message"}'  // Proper JSON since Content-Type is application/json
  }
  
  const result = await handle(Memory, testMsg, env)
  
  // Verify the handler was triggered (underscores converted to dashes)
  assert.ok(result.Output.data.includes('Underscore conversion handler triggered!'))
  assert.ok(result.Output.data.includes('Data-Protocol: test-protocol'))
  assert.ok(result.Output.data.includes('Content-Type: application/json'))
  assert.ok(result.Output.data.includes('Reply-To: test-reply'))
})

test('mixed underscores and dashes normalization', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  // Setup handler that expects consistent dash format
  const setupMsg = {
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
Handlers.add("mixed-format-handler", 
  { 
    ["X-Custom-Header"] = "test-value"
  },
  function(msg)
    print("Mixed format handler triggered!")
    print("X-Custom-Header: " .. (msg.Tags["X-Custom-Header"] or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test various combinations of underscores and dashes
  const testCases = [
    'x_custom_header',
    'X_CUSTOM_HEADER', 
    'x-custom-header',
    'X-CUSTOM-HEADER',
    'x_custom-header',
    'X-custom_HEADER'
  ]
  
  let currentMemory = Memory
  
  for (let i = 0; i < testCases.length; i++) {
    const testMsg = {
      Target: 'AOS',
      From: 'FRED',
      Owner: 'FRED',
      Tags: [
        { name: testCases[i], value: 'test-value' }
      ],
      Data: `test message ${i + 1}`
    }
    
    const result = await handle(currentMemory, testMsg, env)
    assert.ok(result.Output.data.includes('Mixed format handler triggered!'), 
      `Failed for case variation: ${testCases[i]}`)
    assert.ok(result.Output.data.includes('X-Custom-Header: test-value'),
      `Failed to normalize value for: ${testCases[i]}`)
    currentMemory = result.Memory
  }
}) 