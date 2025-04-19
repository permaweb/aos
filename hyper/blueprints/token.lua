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
  -- inputs
  local msg = req.body
  local from = state.getFrom(req)
  -- validations
  assert(type(msg.recipient) == "string", "Recipient is required")
  assert(type(msg.quantity) == "string", "Quantity is required")
  assert(tonumber(msg.quantity) > 0, "Quanity must be greater than 0")
  -- helper functions
  --- Merge two tables, with values from `right` taking precedence.
  -- @param left table The base table
  -- @param right table The overriding table
  -- @treturn table A new table containing all keys from left and right
  local function mergeRight(left, right)
    local result = {}
    -- copy all from left
    for k, v in pairs(left) do
      result[k] = v
    end
    -- override/add from right
    for k, v in pairs(right) do
      result[k] = v
    end
    return result
  end
  -- filter forward keys
  local _forward = Utils.filter(function(s)
    return s:match("^x%-")
  end)
  -- create new table with just forward keys
  local _only = function(filter, msg)
    local keys = Utils.keys(msg)
    return Utils.reduce(function (acc, k)
      acc[k] = msg[k]
      return acc
    end, {}, filter(Utils.keys(msg)))
  end
  
  -- implementation details
  Balances[from] = Balances[from] or 0
  Balances[msg.recipient] = Balances[msg.recipient] or 0
  print("From " .. Balances[from])
  print("To " .. Balances[msg.recipient])
  if tonumber(msg.quantity) <= tonumber(Balances[from]) then
    -- atomically apply transfer
    Balances[from], Balances[msg.recipient] = utils.subtract(Balances[from], msg.quantity), 
      utils.add(Balances[msg.recipient], msg.quantity)

    local resp = {
      recipient = msg.recipient,
      quantity = msg.quantity,
      data = table.concat({ 
        Colors.gray, 
        "Transferred ",
        Colors.blue,
        msg.quantity,
        Colors.gray,
        " to ",
        Colors.green,
        msg.recipient,
        Colors.gray,
        " from ",
        Colors.green,
        from,
        Colors.reset
      })
    }
    resp = mergeRight(resp, _only(_forward, msg))

    if not msg.cast then
      req.reply(mergeRight(resp, {
        action = "Debit-Notice"
      }))
    end
    req.reply(mergeRight(resp, {
      action = "Credit-Notice",
      target = msg.recipient
    }))
  end
  print("transferred")
end


Handlers.add("Mint", mint)
Handlers.add("Balance", getBalance)
Handlers.add("Info", getInfo)
Handlers.add("Balances", getBalances)
Handlers.add("Transfer", transferTo)

