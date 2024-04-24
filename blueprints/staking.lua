Variant = "0.0.2"
Stakers = Stakers or {}
Unstaking = Unstaking or {}
local bint = require('.bint')(256)

--[[
  utils helper functions to remove the bint complexity.
]]
--


local utils = {
  add = function (a,b) 
    return tostring(bint(a) + bint(b))
  end,
  subtract = function (a,b)
    return tostring(bint(a) - bint(b))
  end
}

-- Stake Action Handler
Handlers.stake = function(msg)
  local quantity = bint(msg.Tags.Quantity)
  local delay = tonumber(msg.Tags.UnstakeDelay)
  local height = tonumber(msg['Block-Height'])
  assert(Balances[msg.From] and bint(Balances[msg.From]) >= quantity, "Insufficient balance to stake")
  Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Tags.Quantity) 
  Stakers[msg.From] = Stakers[msg.From] or { amount = "0" }
  Stakers[msg.From].amount = utils.add(Stakers[msg.From].amount, msg.Tags.Quantity)  
  Stakers[msg.From].unstake_at = height + delay
  print("Successfully Staked " .. msg.Tags.Quantity)
  ao.send({Target = msg.From, Data = "Successfully Staked " .. msg.Tags.Quantity})
end

-- Unstake Action Handler
Handlers.unstake = function(msg)
  local stakerInfo = Stakers[msg.From]
  assert(stakerInfo and bint(stakerInfo.amount) >= bint(msg.Tags.Quantity), "Insufficient staked amount")
  stakerInfo.amount = utils.subtract(stakerInfo.amount, msg.Tags.Quantity)
  Unstaking[msg.From] = {
      amount = msg.Quantity,
      release_at = stakerInfo.unstake_at
  }
  ao.send({Target = msg.From, Data = "Successfully unstaked " .. msg.Tags.Quantity})
end

-- Finalization Handler
local finalizationHandler = function(msg)
  local currentHeight = tonumber(msg['Block-Height'])
  -- Process unstaking
  for address, unstakeInfo in pairs(Unstaking) do
      if currentHeight >= unstakeInfo.release_at then
          Balances[address] = utils.add(Balances[address] or "0", unstakeInfo.amount)
          Unstaking[address] = nil
      end
  end
  
end

-- wrap function to continue handler flow
local function continue(fn)
  return function (msg)
    local result = fn(msg)
    if (result) == -1 then
      return "continue"
    end
    return result
  end
end

Handlers.add('staking.balances', Handlers.utils.hasMatchingTag('Action', 'Stakers'),
  function(msg) Send({ Target = msg.From, Data = require('json').encode(Stakers) }) end)
-- Registering Handlers
Handlers.add("staking.stake",
  continue(Handlers.utils.hasMatchingTag("Action", "Stake")), Handlers.stake)
Handlers.add("staking.unstake",
  continue(Handlers.utils.hasMatchingTag("Action", "Unstake")), Handlers.unstake)
-- Finalization handler should be called for every message
-- changed to continue to let messages pass-through
Handlers.add("staking.finalize", function (msg) return "continue" end, finalizationHandler)

