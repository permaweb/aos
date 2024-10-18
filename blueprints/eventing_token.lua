local bint = require('.bint')(256)
local AOEvent = require('ao_event')
local json = require('json')

--[[
  utils helper functions to remove the bint complexity.
]]
--
local utils = {
  add = function(a, b)
    return tostring(bint(a) + bint(b))
  end,
  subtract = function(a, b)
    return tostring(bint(a) - bint(b))
  end,
  toBalanceValue = function(a)
    return tostring(bint(a))
  end,
  toNumber = function(a)
    return bint.tonumber(a)
  end
}


Variant = "0.0.3"
Denomination = Denomination or 12
Balances = Balances or { [ao.id] = utils.toBalanceValue(10000 * 10 ^ Denomination) }
TotalSupply = TotalSupply or utils.toBalanceValue(10000 * 10 ^ Denomination)
Name = Name or 'Eventing Coin'
Ticker = Ticker or 'EVTC'
Logo = Logo or 'SBCCXwwecBlDqRLUjb8dYABExTJXLieawf7m2aBJ-KY'

-- Analytic trackers
NumBalanceRequests = NumBalanceRequests or 0
NumBalancesRequests = NumBalancesRequests or 0
NumInfoRequests = NumInfoRequests or 0
NumTransferRequests = NumTransferRequests or 0
NumMintRequests = NumMintRequests or 0
NumTotalSupplyRequests = NumTotalSupplyRequests or 0
NumTotalBurnRequests = NumTotalBurnRequests or 0

-- Convenience factory function for prepopulating analytic and msg fields into AOEvents
local function EVTCEvent(msg, initialData)
  local event = AOEvent({
    TotalSupply = TotalSupply,
    NumBalanceRequests = NumBalanceRequests,
    NumBalancesRequests = NumBalancesRequests,
    NumInfoRequests = NumInfoRequests,
    NumTransferRequests = NumTransferRequests,
    NumMintRequests = NumMintRequests,
    From = msg.From,
    Cron = msg.Cron or false,
    Cast = msg.Cast or false,
  })
  if initialData ~= nil then
   event:addFields(initialData)
  end
  if msg.Timestamp then
    event:addField("Timestamp", msg.Timestamp)
  end
  return event
end


--[[
     Info
   ]]
--
Handlers.add('info', "Info", function(msg)
  msg.reply({
    Name = Name,
    Ticker = Ticker,
    Logo = Logo,
    Denomination = tostring(Denomination)
  })
  NumInfoRequests = NumInfoRequests + 1
  EVTCEvent(msg, { Action = "Info" }):printEvent()
end)

--[[
     Balance
   ]]
--
Handlers.add('balance', "Balance", function(msg)
  local bal = '0'

  -- If not Recipient is provided, then return the Senders balance
  if (msg.Tags.Recipient) then
    if (Balances[msg.Tags.Recipient]) then
      bal = Balances[msg.Tags.Recipient]
    end
  elseif msg.Tags.Target and Balances[msg.Tags.Target] then
    bal = Balances[msg.Tags.Target]
  elseif Balances[msg.From] then
    bal = Balances[msg.From]
  end

  msg.reply({
    Balance = bal,
    Ticker = Ticker,
    Account = msg.Tags.Recipient or msg.From,
    Data = bal
  })
  NumBalanceRequests = NumBalanceRequests + 1
  EVTCEvent(msg, { Action = "Balance" }):printEvent()
end)

--[[
     Balances
   ]]
--
Handlers.add('balances', "Balances", function(msg)
  msg.reply({ Data = json.encode(Balances) })
  NumBalancesRequests = NumBalancesRequests + 1
  EVTCEvent(msg, { Action = "Balances" }):printEvent()
end)

--[[
     Transfer
   ]]
--
Handlers.add('transfer', "Transfer", function(msg)
  NumTransferRequests = NumTransferRequests + 1
  local aoEvent = EVTCEvent(msg, {
    Action = "Transfer",
    Recipient = msg.Recipient,
    Quantity = msg.Quantity,
  })

  local status, err = pcall(function()
    assert(type(msg.Recipient) == 'string', 'Recipient is required!')
    assert(type(msg.Quantity) == 'string', 'Quantity is required!')
    assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')
  end)

  if not status then
    aoEvent:addField("Error", err)
    aoEvent:printEvent()
    error(err)
  end

  if not Balances[msg.From] then Balances[msg.From] = "0" end
  if not Balances[msg.Recipient] then Balances[msg.Recipient] = "0" end

  aoEvent:addFields({
    SenderStartingBalance = Balances[msg.From],
    RecipientStartingBalance = Balances[msg.Recipient]
  })

  if bint(msg.Quantity) <= bint(Balances[msg.From]) then
    Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Quantity)
    Balances[msg.Recipient] = utils.add(Balances[msg.Recipient], msg.Quantity)

    --[[
        Only send the notifications to the Sender and Recipient
        if the Cast tag is not set on the Transfer message
      ]]
    --
    if not msg.Cast then
      -- Debit-Notice message template, that is sent to the Sender of the transfer
      local debitNotice = {
        Action = 'Debit-Notice',
        Recipient = msg.Recipient,
        Quantity = msg.Quantity,
        Data = Colors.gray ..
            "You transferred " ..
            Colors.blue .. msg.Quantity .. Colors.gray .. " to " .. Colors.green .. msg.Recipient .. Colors.reset
      }
      -- Credit-Notice message template, that is sent to the Recipient of the transfer
      local creditNotice = {
        Target = msg.Recipient,
        Action = 'Credit-Notice',
        Sender = msg.From,
        Quantity = msg.Quantity,
        Data = Colors.gray ..
            "You received " ..
            Colors.blue .. msg.Quantity .. Colors.gray .. " from " .. Colors.green .. msg.From .. Colors.reset
      }

      -- Add forwarded tags to the credit and debit notice messages
      local forwardedTags = {}
      for tagName, tagValue in pairs(msg) do
        -- Tags beginning with "X-" are forwarded
        if string.sub(tagName, 1, 2) == "X-" then
          forwardedTags[tagName] = tagValue
          debitNotice[tagName] = tagValue
          creditNotice[tagName] = tagValue
        end
      end

      if next(forwardedTags) ~= nil then aoEvent:addField("ForwardedTags", json.encode(forwardedTags)) end

      -- Send Debit-Notice and Credit-Notice
      msg.reply(debitNotice)
      Send(creditNotice)
    end
  else
    msg.reply({
      Action = 'Transfer-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Insufficient Balance!'
    })
    aoEvent:addField("Error", "Insufficient Balance!")
  end
  aoEvent:addFields({
    SenderEndingBalance = Balances[msg.From],
    RecipientEndingBalance = Balances[msg.Recipient]
  })
  aoEvent:printEvent()
end)

--[[
    Mint
   ]]
--
Handlers.add('mint', "Mint", function(msg)
  NumMintRequests = NumMintRequests + 1
  local aoEvent = EVTCEvent(msg, {
    Action = "Mint",
    Quantity = msg.Quantity,
  })

  local status, err = pcall(function()
    assert(type(msg.Quantity) == 'string', 'Quantity is required!')
    assert(bint(0) < bint(msg.Quantity), 'Quantity must be greater than zero!')
  end)

  if not status then
    aoEvent:addField("Error", err)
    aoEvent:printEvent()
    error(err)
  end

  if not Balances[ao.id] then Balances[ao.id] = "0" end
  aoEvent:addField("PreMintTotalSupply", TotalSupply)

  if msg.From == ao.id then
    -- Add tokens to the token pool, according to Quantity
    Balances[msg.From] = utils.add(Balances[msg.From], msg.Quantity)
    TotalSupply = utils.add(TotalSupply, msg.Quantity)
    msg.reply({
      Data = Colors.gray .. "Successfully minted " .. Colors.blue .. msg.Quantity .. Colors.reset
    })
    aoEvent:addField("PostMintTotalSupply", TotalSupply)
  else
    local errMsg = 'Only the Process Id can mint new ' .. Ticker .. ' tokens!'
    msg.reply({
      Action = 'Mint-Error',
      ['Message-Id'] = msg.Id,
      Error = errMsg
    })
    aoEvent:addField("Error", errMsg)
  end
  aoEvent:printEvent()
end)

--[[
     Total Supply
   ]]
--
Handlers.add('totalSupply', "Total-Supply", function(msg)
  NumTotalSupplyRequests = NumTotalSupplyRequests + 1
  local aoEvent = EVTCEvent(msg, {
    Action = "Total-Supply"
  })
  local status, err = pcall(function()
    assert(msg.From ~= ao.id, 'Cannot call Total-Supply from the same process!')
  end)

  if not status then
    aoEvent:addField("Error", err)
    aoEvent:printEvent()
    error(err)
  end
  
  msg.reply({
    Action = 'Total-Supply',
    Data = TotalSupply,
    Ticker = Ticker
  })
  aoEvent:printEvent()
end)

--[[
 Burn
]] --
Handlers.add('burn', 'Burn', function(msg)
  NumTotalBurnRequests = NumTotalBurnRequests + 1
  local aoEvent = EVTCEvent(msg, {
    Action = 'Burn',
    Quantity = msg.Quantity
  })

  local status, err = pcall(function()
    assert(type(msg.Quantity) == 'string', 'Quantity is required!')
    assert(bint(msg.Quantity) <= bint(Balances[msg.From]), 'Quantity must be less than or equal to the current balance!')
  end)

  if not status then
    aoEvent:addField("Error", error)
    aoEvent:printEvent()
    error(err)
  end
  
  aoEvent:addField("PreBurnTotalSupply", TotalSupply)
  Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Quantity)
  TotalSupply = utils.subtract(TotalSupply, msg.Quantity)
  aoEvent:addField("PostBurnTotalSupply", TotalSupply)

  msg.reply({
    Data = Colors.gray .. "Successfully burned " .. Colors.blue .. msg.Quantity .. Colors.reset
  })
  aoEvent:printEvent()
end)
