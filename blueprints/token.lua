--[[
  Author: ItsJackAnton
  Twitter: ItsJackAnton
  Discord: ItsJackAnton

  Made: 30/Jun/2024

  Description: AO Blueprint Token Extension V2.
]]--

local bint = require('.bint')(256)
local ao = require('ao')
--[[
  Token Blueprint Version: V2.

  This module is an extencion of the the ao Standard Token implementation that can be found here: https://github.com/permaweb/aos/blob/main/blueprints/token.lua

  Terms:
    Sender: the wallet or Process that sent the Message

  It will first initialize the internal state, and then attach handlers,
    according to the ao Standard Token Spec API:

    - Info(): return the token parameters, like Name, Ticker, Logo, and Denomination

    - Balance(Target?: string): return the token balance of the Target. If Target is not provided, the Sender
        is assumed to be the Target

    - Balances(): return the token balance of all participants

    - Transfer(Target: string, Quantity: number): if the Sender has a sufficient balance, send the specified Quantity
        to the Target. It will also issue a Credit-Notice to the Target and a Debit-Notice to the Sender

    - Mint(Quantity: number): if the Sender matches the Process Owner, then mint the desired Quantity of tokens, adding
        them the Processes' balance
    
    - Approve(Spender: string, Quantity: number): approve someone else to spend on your belhalf

    - Approval(Allower: string, Spender: string): it returns how much the "Spender" can spend on behalf of the "Allower"

    - Approvals(Allower: string): it returns all the spenders and how much they can spend on behalf of a specified "Allower"

    - TransferFrom(Allower: string, Spender: string, Quantity: numeric): it allows an user or process to transfer on behalf of some other user or process.

    What is new?
    1- Extracted the transfer logic from the transfer handler to re-use the transfer logic in the "TransferFrom" handler.
    2- Implemented the "Approve" handler
    3- Implemented the "Approval" handler
    3- Implemented the "Approvals" handler
    4- Implemented the "TransferFrom" handler

    Summary:
    Now users and processes can approve someone else to spend tokens on their behalf.
]]
--
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
    return tonumber(a)
  end
}


--[[
     Initialize State

     ao.id is equal to the Process.Id
   ]]
--
Variant = "0.0.3"

-- token should be idempotent and not change previous state updates
Denomination = Denomination or 12
Balances = Balances or { [ao.id] = utils.toBalanceValue(10000 * 10 ^ Denomination) }
Allowance = Allowance or { }
TotalSupply = TotalSupply or utils.toBalanceValue(10000 * 10 ^ Denomination)
Name = Name or 'Points Coin'
Ticker = Ticker or 'PNTS'
Logo = Logo or 'SBCCXwwecBlDqRLUjb8dYABExTJXLieawf7m2aBJ-KY'

--[[
     Add handlers for each incoming Action defined by the ao Standard Token Specification
   ]]
--

--[[
     Info
   ]]
--
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
  ao.send({
    Target = msg.From,
    Name = Name,
    Ticker = Ticker,
    Logo = Logo,
    Denomination = tostring(Denomination),
    -- Data = Colors.gray .. "Name: \"" .. Name .. "\" | Ticker: \"" .. Ticker .. "\" | Logo: \"" .. Logo .. "\" | Denomination: \"" .. Denomination .. "\"" .. Colors.reset;
  })
end)

--[[
     Balance
   ]]
--
Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
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

  ao.send({
    Target = msg.From,
    Balance = bal,
    Ticker = Ticker,
    Account = msg.Tags.Recipient or msg.From,
    Data = bal
  })
end)

--[[
     Balances
   ]]
--
Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'),
  function(msg) ao.send({ Target = msg.From, Data = json.encode(Balances) }) end)

--[[
     Transfer
   ]]
--
local transfer = function (from, to, quantity, msg);
  if not Balances[from] then Balances[from] = "0" end
  if not Balances[to] then Balances[to] = "0" end

  if bint(quantity) <= bint(Balances[from]) then
    Balances[from] = utils.subtract(Balances[from], quantity)
    Balances[to] = utils.add(Balances[to], quantity)

    --[[
         Only send the notifications to the Sender and Recipient
         if the Cast tag is not set on the Transfer message
       ]]
    --
    if not msg.Cast then
      -- Debit-Notice message template, that is sent to the Sender of the transfer
      local debitNotice = {
        Target = from,
        Action = 'Debit-Notice',
        Recipient = to,
        Quantity = quantity,
        Data = Colors.gray ..
            "You transferred " ..
            Colors.blue .. quantity .. Colors.gray .. " to " .. Colors.green .. to .. Colors.reset
      }
      -- Credit-Notice message template, that is sent to the Recipient of the transfer
      local creditNotice = {
        Target = to,
        Action = 'Credit-Notice',
        Sender = from,
        Quantity = quantity,
        Data = Colors.gray ..
            "You received " ..
            Colors.blue .. quantity .. Colors.gray .. " from " .. Colors.green .. msg.From .. Colors.reset
      }

      -- Add forwarded tags to the credit and debit notice messages
      for tagName, tagValue in pairs(msg) do
        -- Tags beginning with "X-" are forwarded
        if string.sub(tagName, 1, 2) == "X-" then
          debitNotice[tagName] = tagValue
          creditNotice[tagName] = tagValue
        end
      end

      -- Send Debit-Notice and Credit-Notice
      ao.send(debitNotice)
      ao.send(creditNotice)
    end
  else
    ao.send({
      Target = msg.From,
      Action = 'Transfer-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Insufficient Balance!'
    })
  end
end;


Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg)
  assert(type(msg.Recipient) == 'string', 'Recipient is required!')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')

  transfer(msg.From, msg.Recipient, msg.Quantity, msg);
end)

--[[
  Approve
]]--

Handlers.add('approve', Handlers.utils.hasMatchingTag('Action', 'Approve'), function(msg)
  assert(type(msg.Spender) == 'string', 'Recipient is required!')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')

  Allowance[msg.From] = Allowance[msg.From] or {}

  local spenders = Allowance[msg.From]

  spenders[msg.Spender] = spenders[msg.Spender] or "0"
  spenders[msg.Spender] = utils.add(spenders[msg.Spender], msg.Quantity)

  Handlers.utils.reply("You have allowed +" .. msg.Quantity .. " to: " .. msg.Spender .. "\nSpender can use up to: " .. spenders[msg.Spender])(msg)
end)

--[[
  Approval
]]--

Handlers.add('approval', Handlers.utils.hasMatchingTag('Action', 'Approval'), function(msg)
  assert(type(msg.Allower) == 'string', 'Allower is required!')
  assert(type(msg.Spender) == 'string', 'Spender is required!')

  if not Allowance[msg.Allower] then
    
    Handlers.utils.reply("Spender: \'" .. msg.Spender .. "\' can spend a total of: " .. 0 .. " from: \'" .. msg.Allower .. "\'")(msg)

    return
  end

  local spenders = Allowance[msg.Allower]

  if not spenders[msg.Spender] then

    Handlers.utils.reply("Spender: \'" .. msg.Spender .. "\' can spend a total of: " .. 0 .. " from: \'" .. msg.Allower .. "\'")(msg)

    return
  end

  Handlers.utils.reply("Spender: \'" .. msg.Spender .. "\' can spend a total of: " .. spenders[msg.Spender] .. " from: \'" .. msg.Allower .. "\'")(msg)
end)

--[[
  Approvals
]]--

Handlers.add('approvals', Handlers.utils.hasMatchingTag('Action', 'Approvals'), function(msg)
  assert(type(msg.Allower) == 'string', 'Allower is required!')

  if not Allowance[msg.Allower] then
    
    Handlers.utils.reply("Spender: \'" .. msg.Spender .. "\' can spend a total of: " .. 0 .. " from: \'" .. msg.Allower .. "\'")(msg)

    return
  end

  local spenders = Allowance[msg.Allower]

  Handlers.utils.reply("Spenders: " .. json.encode(spenders))(msg)
end)

--[[
  TransferFrom
]]--

Handlers.add('transferFrom', Handlers.utils.hasMatchingTag('Action', 'TransferFrom'), function(msg)
  assert(type(msg.Allower) == 'string', 'Allower is required!')
  assert(type(msg.Recipient) == 'string', 'Recipient is required!')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(Allowance[msg.Allower] ~= nil, 'Allower has not allowed you to handle anything!')
  assert(Allowance[msg.Allower][msg.From] ~= nil, 'Allower has not allowed you to handle anything!')
  assert(bint.__le(bint(msg.Quantity), bint(Allowance[msg.Allower][msg.From])), 'Quantity must greather or equal to ' .. tostring(Allowance[msg.Allower][msg.From])..", current cuantity: " .. msg.Quantity)
  
  Allowance[msg.From] = Allowance[msg.Allower] or {}

  local spenders = Allowance[msg.Allower]

  spenders[msg.Spender] = spenders[msg.Spender] or "0"
  spenders[msg.Spender] = utils.subtract(spenders[msg.Spender], msg.Quantity)

  if spenders[msg.Spender] == "0" then

    spenders[msg.Spender] = nil;

  end

  transfer(msg.Allower, msg.From, msg.Quantity, msg);
end)

--[[
    Mint
   ]]
--
Handlers.add('mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), function(msg)
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint(0) < bint(msg.Quantity), 'Quantity must be greater than zero!')

  if not Balances[ao.id] then Balances[ao.id] = "0" end

  if msg.From == ao.id then
    -- Add tokens to the token pool, according to Quantity
    Balances[msg.From] = utils.add(Balances[msg.From], msg.Quantity)
    TotalSupply = utils.add(TotalSupply, msg.Quantity)
    ao.send({
      Target = msg.From,
      Data = Colors.gray .. "Successfully minted " .. Colors.blue .. msg.Quantity .. Colors.reset
    })
  else
    ao.send({
      Target = msg.From,
      Action = 'Mint-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Only the Process Id can mint new ' .. Ticker .. ' tokens!'
    })
  end
end)

--[[
     Total Supply
   ]]
--
Handlers.add('totalSupply', Handlers.utils.hasMatchingTag('Action', 'Total-Supply'), function(msg)
  assert(msg.From ~= ao.id, 'Cannot call Total-Supply from the same process!')

  ao.send({
    Target = msg.From,
    Action = 'Total-Supply',
    Data = TotalSupply,
    Ticker = Ticker
  })
end)

--[[
 Burn
]] --
Handlers.add('burn', Handlers.utils.hasMatchingTag('Action', 'Burn'), function(msg)
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint(msg.Quantity) <= bint(Balances[msg.From]), 'Quantity must be less than or equal to the current balance!')

  Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Quantity)
  TotalSupply = utils.subtract(TotalSupply, msg.Quantity)

  ao.send({
    Target = msg.From,
    Data = Colors.gray .. "Successfully burned " .. Colors.blue .. msg.Quantity .. Colors.reset
  })
end)