-- Simple test for case-insensitive matching
print("Setting up case-insensitive test handler...")

-- Test the simplified case-insensitive matching
print("\nRunning simplified case-insensitive tests...")

-- Test matchesPattern case-insensitive string matching
local testPattern1 = Utils.matchesPattern("test-action", "TEST-ACTION", {})
local testPattern2 = Utils.matchesPattern("test-action", "test-action", {})
local testPattern3 = Utils.matchesPattern("test-action", "Test-Action", {})

print("✅ matchesPattern('test-action', 'TEST-ACTION') = " .. tostring(testPattern1))
print("✅ matchesPattern('test-action', 'test-action') = " .. tostring(testPattern2))
print("✅ matchesPattern('test-action', 'Test-Action') = " .. tostring(testPattern3))

-- Test matchesSpec with case-insensitive key matching
local msg1 = { action = "test-action", Tags = {} }
local msg2 = { Action = "test-action", Tags = {} }
local msg3 = { ACTION = "test-action", Tags = {} }
local msg4 = { Tags = { action = "test-action" } }
local msg5 = { Tags = { Action = "test-action" } }

local spec = { Action = "test-action" }

local test1 = Utils.matchesSpec(msg1, spec)
local test2 = Utils.matchesSpec(msg2, spec)
local test3 = Utils.matchesSpec(msg3, spec)
local test4 = Utils.matchesSpec(msg4, spec)
local test5 = Utils.matchesSpec(msg5, spec)

print("✅ matchesSpec: lowercase action = " .. tostring(test1))
print("✅ matchesSpec: normal Action = " .. tostring(test2))
print("✅ matchesSpec: uppercase ACTION = " .. tostring(test3))
print("✅ matchesSpec: Tags.action = " .. tostring(test4))
print("✅ matchesSpec: Tags.Action = " .. tostring(test5))

-- Add a handler to test real-world usage
Handlers.add(
  "test-case-insensitive",
  { Action = "test-action" },
  function(msg)
    print("🎉 Handler matched! Action: " .. (msg.Action or msg.action or "unknown"))
    print("   Message keys: " .. table.concat(Utils.keys(msg), ", "))
    if msg.Tags then
      print("   Tag keys: " .. table.concat(Utils.keys(msg.Tags), ", "))
    end
  end
)

print("\nTest handler added. Send messages to test:")
print('Send({ Target = ao.id, Action = "test-action" })')
print('Send({ Target = ao.id, action = "test-action" })')
print('Send({ Target = ao.id, ACTION = "test-action" })')