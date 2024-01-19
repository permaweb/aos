Balances = Balances or {}
Stakers = Stakers or {}
Unstaking = Unstaking or {}
Votes = Votes or {}

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

-- Vote Action Handler
Handlers.vote = function(msg)
  local quantity = Stakers[msg.From].amount
  local target = msg.Tags.Target
  local side = msg.Tags.Side
  local deadline = tonumber(msg['Block-Height']) + tonumber(msg.Tags.Deadline)
  assert(quantity > 0, "No staked tokens to vote")
  Votes[target] = Votes[target] or { yay = 0, nay = 0, deadline = deadline }
  Votes[target][side] = Votes[target][side] + quantity
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
  -- Process voting
  for target, voteInfo in pairs(Votes) do
      if currentHeight >= voteInfo.deadline then
          if voteInfo.nay > voteInfo.yay then
              -- Slash the target's stake
              local slashedAmount = Stakers[target] and Stakers[target].amount or 0
              Stakers[target].amount = 0
          end
          -- Clear the vote record after processing
          Votes[target] = nil
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
Handlers.add("vote",
  continue(Handlers.utils.hasMatchingTag("Action", "Vote")), Handlers.vote)
-- Finalization handler should be called for every message
Handlers.add("finalize", function (msg) return -1 end, finalizationHandler)