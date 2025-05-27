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

test('utils.normalize - basic string normalization', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const evalMsg = {
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
-- Test basic string normalization
print("action -> " .. Utils.normalize("action"))
print("ACTION -> " .. Utils.normalize("ACTION"))
print("Action -> " .. Utils.normalize("Action"))
print("data-protocol -> " .. Utils.normalize("data-protocol"))
print("DATA_PROTOCOL -> " .. Utils.normalize("DATA_PROTOCOL"))
print("content-type -> " .. Utils.normalize("content-type"))
print("x-reference -> " .. Utils.normalize("x-reference"))
print("reply-to -> " .. Utils.normalize("reply-to"))
    `
  }
  
  const { Output } = await handle(start, evalMsg, env)
  
  // Verify normalization to title case
  assert.ok(Output.data.includes('action -> Action'))
  assert.ok(Output.data.includes('ACTION -> Action'))
  assert.ok(Output.data.includes('Action -> Action'))
  assert.ok(Output.data.includes('data-protocol -> Data-Protocol'))
  assert.ok(Output.data.includes('DATA_PROTOCOL -> Data_Protocol'))
  assert.ok(Output.data.includes('content-type -> Content-Type'))
  assert.ok(Output.data.includes('x-reference -> X-Reference'))
  assert.ok(Output.data.includes('reply-to -> Reply-To'))
})

test('utils.normalize - edge cases', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const evalMsg = {
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
-- Test edge cases
print("empty string: '" .. Utils.normalize("") .. "'")
print("single char: '" .. Utils.normalize("a") .. "'")
print("numbers: '" .. Utils.normalize("123") .. "'")
print("mixed: '" .. Utils.normalize("test-123_abc") .. "'")
print("non-string: " .. tostring(Utils.normalize(123)))
print("nil: " .. tostring(Utils.normalize(nil)))
    `
  }
  
  const { Output } = await handle(start, evalMsg, env)
  
  // Verify edge case handling
  assert.ok(Output.data.includes("empty string: ''"))
  assert.ok(Output.data.includes("single char: 'A'"))
  assert.ok(Output.data.includes("numbers: '123'"))
  assert.ok(Output.data.includes("mixed: 'Test-123_Abc'"))
  assert.ok(Output.data.includes("non-string: 123"))
  assert.ok(Output.data.includes("nil: nil"))
})

test('utils.matchesSpec - case-insensitive key matching', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const evalMsg = {
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
-- Test case-insensitive key matching
local testMsg = {
  action = "test-action",
  Tags = {
    ["data-protocol"] = "test-protocol",
    ["CONTENT-TYPE"] = "application/json",
    ["Reply_To"] = "test-reply"
  }
}

-- Test various case patterns
local spec1 = { Action = "test-action" }
local spec2 = { ["Data-Protocol"] = "test-protocol" }
local spec3 = { ["Content-Type"] = "application/json" }
local spec4 = { ["Reply-To"] = "test-reply" }

print("Action match: " .. tostring(Utils.matchesSpec(testMsg, spec1)))
print("Data-Protocol match: " .. tostring(Utils.matchesSpec(testMsg, spec2)))
print("Content-Type match: " .. tostring(Utils.matchesSpec(testMsg, spec3)))
print("Reply-To match: " .. tostring(Utils.matchesSpec(testMsg, spec4)))

-- Test combined spec
local combinedSpec = {
  Action = "test-action",
  ["Data-Protocol"] = "test-protocol"
}
print("Combined match: " .. tostring(Utils.matchesSpec(testMsg, combinedSpec)))
    `
  }
  
  const { Output } = await handle(start, evalMsg, env)
  
  // Verify case-insensitive matching works
  assert.ok(Output.data.includes('Action match: true'))
  assert.ok(Output.data.includes('Data-Protocol match: true'))
  assert.ok(Output.data.includes('Content-Type match: true'))
  assert.ok(Output.data.includes('Reply-To match: true'))
  assert.ok(Output.data.includes('Combined match: true'))
})

test('utils.matchesSpec - backward compatibility', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const evalMsg = {
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
-- Test backward compatibility with exact key matches
local testMsg = {
  Action = "test-action",
  Tags = {
    Action = "test-action",
    ["Data-Protocol"] = "test-protocol"
  }
}

-- Should still match exact keys
local spec1 = { Action = "test-action" }
local spec2 = { ["Data-Protocol"] = "test-protocol" }

print("Exact Action match: " .. tostring(Utils.matchesSpec(testMsg, spec1)))
print("Exact Data-Protocol match: " .. tostring(Utils.matchesSpec(testMsg, spec2)))

-- Test with non-matching case
local testMsg2 = {
  action = "different-action",
  Tags = {
    Action = "test-action"
  }
}

local spec3 = { Action = "test-action" }
print("Tag priority match: " .. tostring(Utils.matchesSpec(testMsg2, spec3)))
    `
  }
  
  const { Output } = await handle(start, evalMsg, env)
  
  // Verify backward compatibility
  assert.ok(Output.data.includes('Exact Action match: true'))
  assert.ok(Output.data.includes('Exact Data-Protocol match: true'))
  assert.ok(Output.data.includes('Tag priority match: true'))
})

test('handler pattern matching with case-insensitive keys', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
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
-- Setup handlers with different case patterns
Handlers.add("test-action-handler", 
  { Action = "test-action" },
  function(msg)
    print("Handler matched: Action = " .. (msg.Action or msg.action or "nil"))
  end
)

Handlers.add("test-protocol-handler",
  { ["Data-Protocol"] = "test-protocol" },
  function(msg)
    print("Handler matched: Data-Protocol = " .. (msg.Tags["Data-Protocol"] or msg.Tags["data-protocol"] or "nil"))
  end
)
    `
  }
  
  const { Memory } = await handle(start, setupMsg, env)
  
  // Test message with lowercase action
  const testMsg1 = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'action', value: 'test-action' }
    ],
    Data: 'test message'
  }
  
  const result1 = await handle(Memory, testMsg1, env)
  assert.ok(result1.Output.data.includes('Handler matched: Action = test-action'))
  
  // Test message with different case protocol
  const testMsg2 = {
    Target: 'AOS',
    From: 'FRED',
    Owner: 'FRED',
    Tags: [
      { name: 'data-protocol', value: 'test-protocol' }
    ],
    Data: 'test message'
  }
  
  const result2 = await handle(result1.Memory, testMsg2, env)
  assert.ok(result2.Output.data.includes('Handler matched: Data-Protocol = test-protocol'))
})

test('message normalization integration with handlers', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
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
-- Test that incoming messages are normalized and handlers can match them
Handlers.add("migration-test",
  { 
    Action = "migrate",
    ["Content-Type"] = "application/json",
    ["Data-Protocol"] = "migration-v1"
  },
  function(msg)
    print("Migration handler triggered!")
    print("Action: " .. (msg.Action or "nil"))
    print("Content-Type: " .. (msg.Tags["Content-Type"] or "nil"))
    print("Data-Protocol: " .. (msg.Tags["Data-Protocol"] or "nil"))
    return true
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
      { name: 'content-type', value: 'application/json' },
      { name: 'DATA_PROTOCOL', value: 'migration-v1' }
    ],
    Data: '{"migration": "test"}'
  }
  
  const result = await handle(Memory, migrationMsg, env)
  
  // Verify the handler was triggered and normalization worked
  assert.ok(result.Output.data.includes('Migration handler triggered!'))
  assert.ok(result.Output.data.includes('Action: migrate'))
  assert.ok(result.Output.data.includes('Content-Type: application/json'))
  assert.ok(result.Output.data.includes('Data-Protocol: migration-v1'))
})

test('utils.matchesPattern - function patterns with normalized keys', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)
  
  const evalMsg = {
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
-- Test function patterns work with normalized keys
local testMsg = {
  action = "test-action",
  Tags = {
    ["data-protocol"] = "v1.0.0"
  }
}

-- Function pattern that checks for version format
local versionPattern = function(value, msg)
  return string.match(value, "^v%d+%.%d+%.%d+$") ~= nil
end

local spec = { ["Data-Protocol"] = versionPattern }
print("Version pattern match: " .. tostring(Utils.matchesSpec(testMsg, spec)))

-- Test with non-matching version
testMsg.Tags["data-protocol"] = "invalid-version"
print("Invalid version match: " .. tostring(Utils.matchesSpec(testMsg, spec)))
    `
  }
  
  const { Output } = await handle(start, evalMsg, env)
  
  // Verify function patterns work with normalized keys
  assert.ok(Output.data.includes('Version pattern match: true'))
  assert.ok(Output.data.includes('Invalid version match: false'))
}) 