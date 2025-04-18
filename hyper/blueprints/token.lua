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


Handlers.add("Mint", mint)
