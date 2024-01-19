Stakers = Stakers or {}
Unstaking = Unstaking or {}

-- Stake Action Handler
Handlers.stake = function(msg)
  local quantity = tonumber(msg.Tags.Quantity)
  local delay = tonumber(msg.Tags.UnstakeDelay)
  local height = tonumber(msg['Block-Height'])
  assert(Balances[msg.From] and Balances[msg.From] >= quantity, "Insufficient balance to stake")
  Balances[msg.From] = Balances[msg.From] - quantity
  Stakers[msg.From] = Stakers[msg.From] or {}
  Stakers[msg.From].amount = (Stakers[msg.From].amount or 0) + quantity
  Stakers[msg.From].unstake_at = height + delay
end

-- Unstake Action Handler
Handlers.unstake = function(msg)
  local quantity = tonumber(msg.Tags.Quantity)
  local stakerInfo = Stakers[msg.From]
  assert(stakerInfo and stakerInfo.amount >= quantity, "Insufficient staked amount")
  stakerInfo.amount = stakerInfo.amount - quantity
  Unstaking[msg.From] = {
      amount = quantity,
      release_at = stakerInfo.unstake_at
  }
end

-- Finalization Handler
local finalizationHandler = function(msg)
  local currentHeight = tonumber(msg['Block-Height'])
  -- Process unstaking
  for address, unstakeInfo in pairs(Unstaking) do
      if currentHeight >= unstakeInfo.release_at then
          Balances[address] = (Balances[address] or 0) + unstakeInfo.amount
          Unstaking[address] = nil
      end
  end
  
end

-- wrap function to continue handler flow
local function continue(fn)
  return function (msg)
    local result = fn(msg)
    if (result) == -1 then
      return 1
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
Handlers.add("finalize", function (msg) return -1 end, finalizationHandler)