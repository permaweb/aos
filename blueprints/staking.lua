Stakers = Stakers or {}
Unstaking = Unstaking or {}
local bint = require('.bint')(256)

-- Stake Action Handler
Handlers.stake = function(msg)
  local quantity = bint(msg.Tags.Quantity)
  local delay = tonumber(msg.Tags.UnstakeDelay)
  local height = tonumber(msg['Block-Height'])
  assert(Balances[msg.From] and bint(Balances[msg.From]) >= quantity, "Insufficient balance to stake")
  Balances[msg.From] = tostring(bint(Balances[msg.From]) - quantity)
  Stakers[msg.From] = Stakers[msg.From] or {}
  Stakers[msg.From].amount = tostring(bint(Stakers[msg.From].amount or "0") + quantity)
  Stakers[msg.From].unstake_at = height + delay
  ao.send({Target = msg.From, Data = "Successfully Staked " .. msg.Quantity})
end

-- Unstake Action Handler
Handlers.unstake = function(msg)
  local quantity = bint(msg.Quantity)
  local stakerInfo = Stakers[msg.From]
  assert(stakerInfo and bint(stakerInfo.amount) >= quantity, "Insufficient staked amount")
  stakerInfo.amount = tostring(bint(stakerInfo.amount) - quantity)
  Unstaking[msg.From] = {
      amount = tostring(quantity),
      release_at = stakerInfo.unstake_at
  }
  ao.send({Target = msg.From, Data = "Successfully unstaked " .. msg.Quantity})
end

-- Finalization Handler
local finalizationHandler = function(msg)
  local currentHeight = tonumber(msg['Block-Height'])
  -- Process unstaking
  for address, unstakeInfo in pairs(Unstaking) do
      if currentHeight >= unstakeInfo.release_at then
          Balances[address] = tostring(bint(Balances[address] or "0") + bint(unstakeInfo.amount))
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

-- Registering Handlers
Handlers.add("stake",
  continue(Handlers.utils.hasMatchingTag("Action", "Stake")), Handlers.stake)
Handlers.add("unstake",
  continue(Handlers.utils.hasMatchingTag("Action", "Unstake")), Handlers.unstake)
-- Finalization handler should be called for every message
-- This should be at the end of your handlers list because no message will pass 
-- through here
Handlers.add("finalize", function (msg) return true end, finalizationHandler)