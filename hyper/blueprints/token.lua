local state = require('.state')
local Utils = require('.utils')
local json = require('.json')

local utils = {
  add = function(a, b)
    a = type(a) == 'string' and tonumber(a) or a
    b = type(b) == 'string' and tonumber(b) or b
    return string.format("%i", (a + b))
  end,
  subtract = function(a, b)
    a = type(a) == 'string' and tonumber(a) or a
    b = type(b) == 'string' and tonumber(b) or b

    return string.format("%i", (a - b))
  end,
  toBalanceValue = function(a)
    a = type(a) == 'string' and tonumber(a) or a
    return string.format("%i", a)
  end,
  toNumber = function(a)
    return tonumber(a)
  end
}

-- Global State
Balances = Balances or {}
Name = Name or "Token"
Ticker = Ticker or "TKN"
Logo = Logo or "" -- TODO need generic token image

local function mint(req)
  -- process mints
  local function parseCSV(csvText)
    local result = {}
    for line in csvText:gmatch("[^\r\n]+") do
      local row = {}
      for value in line:gmatch("[^,]+") do table.insert(row, value) end
      table.insert(result, row)
    end
    return result
  end

  local msg = req.body
  local from = state.getFrom(req)

  assert(from == Owner, 'User must be owner to mint')
  assert(msg.format == 'CSV', 'Mint format must be simple csv')
  local mints = parseCSV(msg.data)
  Utils.map(function (mintRequest)
    local address, amount = table.unpack(mintRequest)
    amount = not tonumber(amount) and 0 or tonumber(amount)
    Balances[address] = Balances[address] or "0"
    Balances[address] = utils.add(Balances[address], amount)
  end, mints)

  print('Successfully processed mint request')
end

local function getBalance(req)
  local msg = req.body
  local from = state.getFrom(req)
  local _account = msg.recipient or from
  local _balance = Balances[_account] or "0"
  req.reply({
    ticker = Ticker,
    balance = _balance,
    account = _account,
    data = _balance,
    action = "Balance-Notice"
  })
end

local function getInfo(req)
  req.reply({
    name = Name,
    ticker = Ticker,
    denomination = Denomination
  })
end

local function getBalances(req)
  local mintedSupply = tostring(Utils.reduce(function (acc, v)
    return utils.add(acc, Balances[v])
  end, 0, Utils.keys(Balances)))

  req.reply({
    ticker = Ticker,
    mintedsupply = mintedSupply,
    data = Balances
  })
end

local function transferTo(req)
  local msg = req.body
  local from = state.getFrom(req)
  assert(type(msg.recipient) == "string", "Recipient is required")
  assert(type(msg.quantity) == "string", "Quantity is required")
  assert(tonumber(msg.quantity) > 0, "Quanity must be greater than 0")
  Balances[from] = Balances[from] or 0
  Balances[msg.recipient] = Balances[msg.recipient] or 0

  if tonumber(msg.quantity) >= tonumber(Balances[from]) then
    utils.subtract(Balances[from], msg.quantity)
    utils.add(Balances[msg.recipient], msg.quantity)

    -- TODO: need to add x- tags to credit and debit

    if not msg.cast then
      msg.reply({
        action = "Debit-Notice",
	recipient = msg.recipient,
	quantity = msg.quantity,
	data = table.concat({ 
	  Colors.gray, 
	  "You transferred ",
	  Colors.blue,
	  msg.quantity,
	  Colors.gray,
	  " to ",
	  Colors.green,
	  msg.recipient,
	  Colors.reset
        })
      })
    end

    msg.reply({
      action = "Credit-Notice",
      sender = from,
      recipient = msg.recipient,
      quantity = msg.quantity,
      data = table.concat({
        Colors.gray,
	"You received ",
	Colors.green,
	msg.quantity,
	Colors.gray,
	" from ",
	Colors.green,
	from,
	Colors.reset
i     })
    })
      })

Handlers.add("Mint", mint)
Handlers.add("Balance", getBalance)
Handlers.add("Info", getInfo)
Handlers.add("Balances", getBalances)
Handlers.add("Transfer", transferTo)

