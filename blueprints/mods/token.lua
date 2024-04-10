local bint = require('.bint')(256)
local ao = require('ao')
local json = require('json')


Mod = {}
function Mod.info(msg)
  ao.send({
    Target = msg.From,
    Action = "Response",
    Name = Name,
    Ticker = Ticker,
    Logo = Logo,
    Denomination = tostring(Denomination),
    Nonce = msg.Nonce,
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
    Action = "Response",
    Balance = bal,
    Ticker = Ticker,
    Account = msg.Tags.Target or msg.From,
    Nonce = msg.Nonce,
  })
end

function Mod.balances(msg)
  ao.send({ Target = msg.From, Data = json.encode(Balances), Action = 'Response', Nonce = msg.Nonce, })
end

function Mod.allowance(msg)
  assert(type(msg.Spender) == 'string', 'Spender is required!')
  local allowance = '0'
  -- If no Target is provided, then return the Senders allowance
  if (msg.Tags.Target and Allowances[msg.Tags.Target][msg.Spender]) then
    allowance = Allowances[msg.Tags.Target][msg.Spender]
  elseif Allowances[msg.From][msg.Spender] then
    allowance = Allowances[msg.From][msg.Spender]
  end
  ao.send({
    Target = msg.From,
    Action = 'Response',
    Ticker = Ticker,
    Account = msg.Tags.Target or msg.From,
    Allowance = allowance,
    Nonce = msg.Nonce,
  })
end

function Mod.allowances(msg)
  ao.send({ Target = msg.From, Data = json.encode(Allowances), Action = 'Response', Nonce = msg.Nonce, })
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
    ao.send({
      Target = msg.From,
      Action = 'Response',
      Recipient = msg.Recipient,
      Quantity = tostring(qty),
      Nonce = msg.Nonce,
    })
    ao.send({
      Target = msg.Recipient,
      Action = 'Response',
      Sender = msg.From,
      Quantity = tostring(qty),
      Nonce = msg.Nonce,
    })
  else
    ao.send({
      Target = msg.From,
      Action = 'Transfer-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Insufficient Balance!',
      Nonce = msg.Nonce,
    })
  end
end

function Mod.transferFrom(msg)
  assert(type(msg.OwnerId) == 'string', 'OwnerId is required!')
  assert(type(msg.Recipient) == 'string', 'Recipient is required!')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')

  if not Allowances[msg.OwnerId] then Allowances[msg.OwnerId] = {} end
  if not Allowances[msg.OwnerId][msg.from] then Allowances[msg.OwnerId][msg.from] = 0 end
  if not Balances[msg.OwnerId] then Balances[msg.OwnerId] = "0" end
  if not Balances[msg.Recipient] then Balances[msg.Recipient] = "0" end

  local qty = bint(msg.Quantity)
  local allowance = bint(Allowances[msg.OwnerId][msg.from])
  local balance = bint(Balances[msg.OwnerId])
  if bint.__le(qty, allowance) then
    if bint.__le(qty, balance) then
      Balances[msg.OwnerId] = tostring(bint.__sub(balance, qty))
      Allowances[msg.OwnerId][msg.from] = tostring(bint.__sub(allowance, qty))
      Balances[msg.Recipient] = tostring(bint.__add(Balances[msg.Recipient], qty))
      ao.send({
        Target = msg.OwnerId,
        Action = 'Response',
        Recipient = msg.Recipient,
        Quantity = tostring(qty),
        Nonce = msg.Nonce,
      })
      -- Send Credit-Notice to the Recipient
      ao.send({
        Target = msg.Recipient,
        Action = 'Response',
        Sender = msg.OwnerId,
        Quantity = tostring(qty),
        Nonce = msg.Nonce,
      })
    else
      ao.send({
        Target = msg.from,
        OwnerId = msg.OwnerId,
        Action = 'TransferFrom-Error',
        ['Message-Id'] = msg.Id,
        Error = 'Insufficient Balance!',
        Nonce = msg.Nonce,
      })
    end
  else
    ao.send({
      Target = msg.from,
      OwnerId = msg.OwnerId,
      Action = 'TransferFrom-Error',
      ['Message-Id'] = msg.Id,
      Error = 'Insufficient Allowance!',
      Nonce = msg.Nonce,
    })
  end
end

function Mod.approve(msg)
  assert(type(msg.Spender) == 'string', 'Spender is required!')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')
  if not Allowances[msg.From] then Allowances[msg.From] = {} end
  Allowances[msg.From][msg.Spender] = msg.Quantity
  ao.send({
    Target = msg.From,
    Action = 'Response',
    Nonce = msg.Nonce,
  })
end

function Mod.mint(msg)
  assert(msg.from == Minter, 'Not Authorized')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, msg.Quantity), 'Quantity must be greater than zero!')

  if not Balances[msg.Recipient] then Balances[msg.Recipient] = "0" end
  -- Add tokens to the token pool, according to Quantity
  Balances[msg.Recipient] = tostring(bint.__add(Balances[msg.Recipient], msg.Quantity))
  ao.send({
    Target = msg.From,
    Action = 'Response',
    Nonce = msg.Nonce,
  })
end

function Mod.setMinter(msg)
  --[[
          Allows the Minter to set another processId as the Minter
          If the Minter wants to prevent any future mints they can set the processId to the processId of the token
        ]]
  --
  assert(msg.from == Minter, 'Not Authorized')
  assert(type(msg.Minter) == 'string', 'Minter is required!')
  Minter = msg.Minter
end

function Mod.init(msg)
  ao.isTrusted(msg)
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
