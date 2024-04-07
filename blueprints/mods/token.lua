local bint = require('.bint')(256)
local ao = require('ao')
local json = require('json')

Mod = {}
function Mod.info(msg)
  ao.send({
    Target = msg.From,
    Name = Name,
    Ticker = Ticker,
    Logo = Logo,
    Denomination = tostring(Denomination)
  })
end

function Mod.balance(msg)
  local bal = '0'

  -- If not Target is provided, then return the Senders balance
  if (msg.Tags.Target and Balances[msg.Tags.Target]) then
    bal = Balances[msg.Tags.Target]
  elseif Balances[msg.From] then
    bal = Balances[msg.From]
  end

  ao.send({
    Target = msg.From,
    Balance = bal,
    Ticker = Ticker,
    Account = msg.Tags.Target or msg.From,
    Data = bal
  })
end

function Mod.balances(msg)
  ao.send({ Target = msg.From, Data = json.encode(Balances) })
end

function Mod.allowance(msg)
  assert(type(msg.Spender) == 'string', 'Spender is required!')
  local bal = '0'
  -- If no Target is provided, then return the Senders allowance
  if (msg.Tags.Target and Allowances[msg.Tags.Target][msg.Spender]) then
    bal = Allowances[msg.Tags.Target][msg.Spender]
  elseif Allowances[msg.From][msg.Spender] then
    bal = Allowances[msg.From][msg.Spender]
  end
  ao.send({
    Target = msg.From,
    Balance = bal,
    Ticker = Ticker,
    Account = msg.Tags.Target or msg.From,
    Data = bal
  })
end

function Mod.allowances(msg)
  ao.send({ Target = msg.From, Data = json.encode(Allowances) })
end

function Mod.transfer(msg)
  assert(type(msg.Recipient) == 'string', 'Recipient is required!')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')

  if not Balances[msg.From] then Balances[msg.From] = "0" end
  if not Balances[msg.Recipient] then Balances[msg.Recipient] = "0" end

  local qty = bint(msg.Quantity)
  local balance = bint(Balances[msg.From])
  if bint.__le(qty, balance) then
    Balances[msg.From] = tostring(bint.__sub(balance, qty))
    Balances[msg.Recipient] = tostring(bint.__add(Balances[msg.Recipient], qty))

    --[[
         Only send the notifications to the Sender and Recipient
         if the Cast tag is not set on the Transfer message
       ]]
    --
    if not msg.Cast then
      -- Send Debit-Notice to the Sender
      ao.send({
        Target = msg.From,
        Action = 'Debit-Notice',
        Recipient = msg.Recipient,
        Quantity = tostring(qty),
        Data = Colors.gray ..
            "You transferred " ..
            Colors.blue .. msg.Quantity .. Colors.gray .. " to " .. Colors.green .. msg.Recipient .. Colors.reset
      })
      -- Send Credit-Notice to the Recipient
      ao.send({
        Target = msg.Recipient,
        Action = 'Credit-Notice',
        Sender = msg.From,
        Quantity = tostring(qty),
        Data = Colors.gray ..
            "You received " ..
            Colors.blue .. msg.Quantity .. Colors.gray .. " from " .. Colors.green .. msg.From .. Colors.reset
      })
    end
  else
    ao.send({
      Target = msg.From,
      Action = 'Transfer-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Insufficient Balance!'
    })
  end
end

function Mod.transferFrom(msg)
  assert(type(msg.Owner) == 'string', 'Owner is required!')
  assert(type(msg.Recipient) == 'string', 'Recipient is required!')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')

  if not Allowances[msg.Owner] then Allowances[msg.Owner] = {} end
  if not Allowances[msg.Owner][msg.from] then Allowances[msg.Owner][msg.from] = 0 end
  if not Balances[msg.Owner] then Balances[msg.Owner] = "0" end
  if not Balances[msg.Recipient] then Balances[msg.Recipient] = "0" end

  local qty = bint(msg.Quantity)
  local allowance = bint(Allowances[msg.Owner][msg.from])
  local balance = bint(Balances[msg.Owner])
  if bint.__le(qty, allowance) then
    if bint.__le(qty, balance) then
      Balances[msg.Owner] = tostring(bint.__sub(balance, qty))
      Allowances[msg.Owner][msg.from] = tostring(bint.__sub(allowance, qty))
      Balances[msg.Recipient] = tostring(bint.__add(Balances[msg.Recipient], qty))

      --[[
          Only send the notifications to the Owner and Recipient
          if the Cast tag is not set on the TransferFrom message
        ]]
      --
      if not msg.Cast then
        -- Send Debit-Notice to the Owner
        ao.send({
          Target = msg.Owner,
          Action = 'Debit-Notice',
          Recipient = msg.Recipient,
          Quantity = tostring(qty),
          Data = Colors.gray ..
              "You transferred " ..
              Colors.blue .. msg.Quantity .. Colors.gray .. " to " .. Colors.green .. msg.Recipient .. Colors.reset
        })
        -- Send Credit-Notice to the Recipient
        ao.send({
          Target = msg.Recipient,
          Action = 'Credit-Notice',
          Sender = msg.Owner,
          Quantity = tostring(qty),
          Data = Colors.gray ..
              "You received " ..
              Colors.blue .. msg.Quantity .. Colors.gray .. " from " .. Colors.green .. msg.From .. Colors.reset
        })
      end
    else
      ao.send({
        Target = msg.Owner,
        Action = 'Transfer-Error',
        ['Message-Id'] = msg.Id,
        Error = 'Insufficient Balance!'
      })
    end
  else
    ao.send({
      Target = msg.Owner,
      Action = 'Transfer-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Insufficient Allowance!'
    })
  end
end

function Mod.approve(msg)
  assert(type(msg.Spender) == 'string', 'Spender is required!')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')
  if not Allowances[msg.From] then Allowances[msg.From] = {} end
  Allowances[msg.From][msg.Spender] = msg.Quantity
end

function Mod.mint(msg)
  assert(msg.from == Minter, 'Not Authorized')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, msg.Quantity), 'Quantity must be greater than zero!')

  if not Balances[ao.id] then Balances[ao.id] = "0" end

  if msg.From == ao.id then
    -- Add tokens to the token pool, according to Quantity
    Balances[msg.From] = tostring(bint.__add(Balances[Owner], msg.Quantity))
    ao.send({
      Target = msg.From,
      Data = Colors.gray .. "Successfully minted " .. Colors.blue .. msg.Quantity .. Colors.reset
    })
  else
    ao.send({
      Target = msg.From,
      Action = 'Mint-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Only the Process Owner can mint new ' .. Ticker .. ' tokens!'
    })
  end
end

function Mod.init(msg)
  assert(type(msg.Minter) == 'string', 'Minter is required!')
  assert(type(msg.Name) == 'string', 'Name is required!')
  assert(type(msg.Ticker) == 'string', 'Ticker is required!')
  assert(type(msg.Logo) == 'string', 'Logo is required!')
  assert(type(msg.Denomination) == 'string', 'Denomination is required!')
  assert(bint.__lt(0, msg.Denomination), 'Denomination must be greater than zero!')
  
  assert(Minter == '', 'Not Authorized')
  assert(Name == '', 'Not Authorized')
  assert(Ticker == '', 'Not Authorized')
  assert(Logo == '', 'Not Authorized')

  Minter = msg.Minter
  Name = msg.Name
  Ticker = msg.Ticker
  Logo = msg.Logo
  Denomination = bint(msg.Denomination)
end

return Mod
