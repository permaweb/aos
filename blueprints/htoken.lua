local bint = require('.bint')(256)
--[[
  This module implements the ao Standard Token Specification.

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
    return bint.tonumber(a)
  end
}


--[[
     Initialize State

     ao.id is equal to the Process.Id
   ]]
--
Variant = "0.0.4"

-- token should be idempotent and not change previous state updates
Denomination = Denomination or 12
Balances = Balances or { [id] = utils.toBalanceValue(10000 * 10 ^ Denomination) }
TotalSupply = TotalSupply or utils.toBalanceValue(10000 * 10 ^ Denomination)
Name = Name or 'Hyper Test Coin'
Ticker = Ticker or 'HYPER'
Logo = Logo or 'eskTHZQzCLOFrpzkr7zeaf4RxmkaNVYvHuPLh4CLpX4'

--[[
     Add handlers for each incoming Action defined by the ao Standard Token Specification
   ]]
--

--[[
     Info
   ]]
--
Handlers.add('info', function(msg)
  send({
    Target = msg.from,
    Name = Name,
    Ticker = Ticker,
    Logo = Logo,
    Denomination = tostring(Denomination)
 })
end)

--[[
     Balance
   ]]
--
Handlers.add('balance', { action = "balance"}, function(msg)
  local bal = '0'
  print('balance called')
  print('from ' .. msg.from)

  -- If not Recipient is provided, then return the Senders balance
  if (msg.recipient) then
    if (Balances[msg.recipient]) then
      bal = Balances[msg.recipient]
    end
  elseif msg.target and Balances[msg.target] then
    bal = Balances[msg.target]
  elseif Balances[msg.from] then
    bal = Balances[msg.from]
  end
  send({
    target = msg.from,
    balance = bal,
    ticker = Ticker,
    account = msg.recipient or msg.from,
    data = bal
  })
end)

--[[
     Balances
   ]]
--
Handlers.add('balances',
  function(msg) 
    send({target = msg.from, data = json.encode(Balances) }) 
  end)

--[[
     Transfer
   ]]
--
Handlers.add('transfer', function(msg)
  assert(type(msg.recipient) == 'string', 'Recipient is required!')
  assert(type(msg.quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, bint(msg.quantity)), 'Quantity must be greater than 0')

  if not Balances[msg.from] then Balances[msg.from] = "0" end
  if not Balances[msg.recipient] then Balances[msg.recipient] = "0" end

  if bint(msg.quantity) <= bint(Balances[msg.from]) then
    Balances[msg.from] = utils.subtract(Balances[msg.from], msg.quantity)
    Balances[msg.recipient] = utils.add(Balances[msg.recipient], msg.quantity)

    --[[
         Only send the notifications to the Sender and Recipient
         if the Cast tag is not set on the Transfer message
       ]]
    --
    if not msg.cast then
      -- Debit-Notice message template, that is sent to the Sender of the transfer
      local debitNotice = {
        action = 'Debit-Notice',
        recipient = msg.recipient,
        quantity = msg.quantity,
        data = colors.gray ..
            "You transferred " ..
            colors.blue .. msg.quantity .. colors.gray .. " to " .. colors.green .. msg.recipient .. colors.reset
      }
      -- Credit-Notice message template, that is sent to the Recipient of the transfer
      local creditNotice = {
        target = msg.recipient,
        action = 'Credit-Notice',
        sender = msg.from,
        quantity = msg.quantity,
        data = colors.gray ..
            "You received " ..
            colors.blue .. msg.quantity .. colors.gray .. " from " .. colors.green .. msg.from .. colors.reset
      }

      -- Add forwarded tags to the credit and debit notice messages
      for tagName, tagValue in pairs(msg) do
        -- Tags beginning with "X-" are forwarded
        if string.sub(tagName, 1, 2) == "x-" then
          debitNotice[tagName] = tagValue
          creditNotice[tagName] = tagValue
        end
      end

      -- Send Debit-Notice and Credit-Notice
      debitNotice.Target = msg.from
      send(debitNotice)
      send(creditNotice)
    end
  else
    send({
      target = msg.from,
      action = 'Transfer-Error',
      ['Message-Id'] = msg.id,
      error = 'Insufficient Balance!'
    })
  end
end)

--[[
    Mint
   ]]
--
Handlers.add('mint', function(msg)
  assert(type(msg.quantity) == 'string', 'Quantity is required!')
  assert(bint(0) < bint(msg.quantity), 'Quantity must be greater than zero!')

  if not Balances[id] then Balances[id] = "0" end

  if msg.from == id then
    -- Add tokens to the token pool, according to Quantity
    Balances[msg.from] = utils.add(Balances[msg.from], msg.quantity)
    TotalSupply = utils.add(TotalSupply, msg.quantity)
    send({
      target = msg.from,
      data = colors.gray .. "Successfully minted " .. colors.blue .. msg.quantity .. colors.reset
    })
  else
    send({
      target = msg.from,
      action = 'Mint-Error',
      ['Message-Id'] = msg.id,
      error = 'Only the Process Id can mint new ' .. Ticker .. ' tokens!'
    })
  end
end)

--[[
     Total Supply
   ]]
--
Handlers.add('totalSupply', function(msg)
  assert(msg.From ~= id, 'Cannot call Total-Supply from the same process!')
  send({
    Target = msg.From,
    Action = 'Total-Supply',
    Data = TotalSupply,
    Ticker = Ticker
  })
end)


