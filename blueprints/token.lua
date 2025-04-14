local bint = require('.bint')(256)
--[[
  This module implements the ao Standard Token Specification (Vanilla version).
  It provides core token functionalities without external dependencies beyond bint.

  Supported Actions (Handlers):
    - Info(): Returns token parameters (Name, Ticker, Logo, Denomination).
    - Balance(Target?: string): Returns the token balance of the Target.
                                If Target is not provided, uses the Sender.
    - Balances(): Returns the token balances of all participants.
    - Transfer(Recipient: string, Quantity: string): Sends tokens from Sender to Recipient.
                                                  Issues Debit-Notice and Credit-Notice.
    - Batch-Transfer(Data: string): Processes multiple transfers atomically from CSV data.
                                     CSV format: recipient,quantity (one per line, newline separated).
                                     Issues Batch-Debit-Notice and optional Credit-Notices.
    - Mint(Quantity: string): Mints new tokens to the process owner's balance 
                                (if Sender is the process owner).
    - Burn(Quantity: string): Burns tokens from the Sender's balance.
    - TotalSupply(): Returns the current total supply of the token.

  Terms:
    Sender: The wallet or Process that sent the Message.
    Target/Recipient: The destination wallet or Process for queries or transfers.
]]
--
local json = require('json')

--[[----------------------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------------------]]

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

--[[----------------------------------------------------------------------------
-- Input Validation Helpers
----------------------------------------------------------------------------]]

-- Validates quantity format (required, string, digits, positive).
-- @param quantity (string) The quantity to validate.
-- @param context (string) Context for error messages.
local function validateQuantity(quantity, context)
  context = context or "Input"
  assert(quantity and type(quantity) == 'string', context .. ': Quantity (string) is required.')
  assert(string.match(quantity, "^%d+$"), context .. ': Quantity must contain only digits.')
  assert(bint.ispos(bint(quantity)), context .. ': Quantity must be greater than 0.')
end

-- Validates recipient and quantity for a transfer.
-- @param recipient (string) The recipient address.
-- @param quantity (string) The quantity to transfer (as a string).
-- @param context (string) Context for error messages.
local function validateTransferInput(recipient, quantity, context)
  context = context or "TransferInput"
  assert(recipient and type(recipient) == 'string' and recipient ~= '', context .. ': Recipient is required.')
  validateQuantity(quantity, context)
end

--[[----------------------------------------------------------------------------
-- Tag Forwarding Helper
----------------------------------------------------------------------------]]

-- Copies tags starting with "X-" from a message to a target table.
-- @param msg The source message table.
-- @param targetTable The table to copy tags into.
local function forwardXTags(msg, targetTable)
  for tagName, tagValue in pairs(msg) do
    -- Check if tagValue is a string to avoid errors with complex types
    if type(tagName) == 'string' and string.sub(tagName, 1, 2) == "X-" then
      targetTable[tagName] = tagValue
    end
  end
end

--[[----------------------------------------------------------------------------
-- Response Helper
----------------------------------------------------------------------------]]

-- Sends a response either via msg.reply or Send.
-- @param msg The incoming message object.
-- @param data The data payload for the response.
local function sendResponse(msg, data)
  if msg.reply then
    msg.reply(data)
  else
    if not data.Target then data.Target = msg.From end
    Send(data)
  end
end

--[[----------------------------------------------------------------------------
-- State Initialization
----------------------------------------------------------------------------]]

Variant = "0.0.3"

Denomination = Denomination or 12
Balances = Balances or { [ao.id] = utils.toBalanceValue(10000 * 10 ^ Denomination) }
TotalSupply = TotalSupply or utils.toBalanceValue(10000 * 10 ^ Denomination)
Name = Name or 'Points Coin'
Ticker = Ticker or 'PNTS'
Logo = Logo or 'SBCCXwwecBlDqRLUjb8dYABExTJXLieawf7m2aBJ-KY'


--[[----------------------------------------------------------------------------
-- Handlers
----------------------------------------------------------------------------]]

--[[ Info ]]--
Handlers.add('info', Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
  local replyData = { Name = Name, Ticker = Ticker, Logo = Logo, Denomination = tostring(Denomination) }
  sendResponse(msg, replyData)
end)

--[[ Balance ]]--
Handlers.add('balance', Handlers.utils.hasMatchingTag("Action", "Balance"), function(msg)
  local bal = '0'
  local targetAccount = msg.Tags.Target or msg.Tags.Recipient or msg.From
  if Balances[targetAccount] then bal = Balances[targetAccount] end
  local replyData = { Balance = bal, Ticker = Ticker, Account = targetAccount, Data = bal }
  sendResponse(msg, replyData)
end)

--[[ Balances ]]--
Handlers.add('balances', Handlers.utils.hasMatchingTag("Action", "Balances"), function(msg) 
  local data = { Data = json.encode(Balances) }
  sendResponse(msg, data)
end)

--[[ Transfer ]]--
Handlers.add('transfer', Handlers.utils.hasMatchingTag("Action", "Transfer"), function(msg)
  local recipient = msg.Recipient
  local quantity = msg.Quantity
  
  validateTransferInput(recipient, quantity, "Transfer")

  -- Check balance and perform transfer atomically
  if not Balances[msg.From] then Balances[msg.From] = "0" end
  if not Balances[recipient] then Balances[recipient] = "0" end
  
  if bint(quantity) <= bint(Balances[msg.From]) then
    Balances[msg.From] = utils.subtract(Balances[msg.From], quantity)
    Balances[recipient] = utils.add(Balances[recipient], quantity)
    
    -- Send notices if Cast is not set
    if not msg.Cast then
      local debitNotice = { Action = 'Debit-Notice', Recipient = recipient, Quantity = quantity,
                          Data = Colors.gray .. "You transferred " .. Colors.blue .. quantity .. Colors.gray .. " to " .. Colors.green .. recipient .. Colors.reset }
      local creditNotice = { Target = recipient, Action = 'Credit-Notice', Sender = msg.From, Quantity = quantity,
                           Data = Colors.gray .. "You received " .. Colors.blue .. quantity .. Colors.gray .. " from " .. Colors.green .. msg.From .. Colors.reset }
      forwardXTags(msg, debitNotice)
      forwardXTags(msg, creditNotice)
      sendResponse(msg, debitNotice)
      Send(creditNotice)
    end
  else
    -- Handle insufficient balance
    local err_data = { Action = 'Transfer-Error', ['Message-Id'] = msg.Id, Error = 'Insufficient Balance!' }
    sendResponse(msg, err_data)
  end
end)

--[[ Batch-Transfer ]]--
Handlers.add('batch-transfer', Handlers.utils.hasMatchingTag("Action", "Batch-Transfer"), function(msg)
  -- Internal CSV Parser
  local function parseCSV(csvText) 
    local result = {}
    for line in csvText:gmatch("[^\r\n]+") do
      local row = {}
      for value in line:gmatch("[^,]+") do table.insert(row, value) end
      table.insert(result, row)
    end
    return result
  end

  -- Step 1: Parse CSV data and validate entries
  local rawRecords = parseCSV(msg.Data)
  assert(rawRecords and #rawRecords > 0, 'No transfer entries found in CSV')
  local transferEntries, totalQuantity, balanceIncreases = {}, "0", {}
  for i, record in ipairs(rawRecords) do
      local recipient, quantity = record[1], record[2]
      validateTransferInput(recipient, quantity, "Batch line " .. i)
      table.insert(transferEntries, { Recipient = recipient, Quantity = quantity })
      totalQuantity = utils.add(totalQuantity, quantity)
      -- Aggregate increases per recipient
      if not balanceIncreases[recipient] then balanceIncreases[recipient] = quantity
      else balanceIncreases[recipient] = utils.add(balanceIncreases[recipient], quantity) end
  end
  
  -- Step 2: Check sender balance
  if not Balances[msg.From] then Balances[msg.From] = "0" end
  if not (bint(totalQuantity) <= bint(Balances[msg.From])) then
     local err_data = { Action = 'Transfer-Error', ['Message-Id'] = msg.Id, Error = 'Insufficient Balance!' }
     msg.reply(err_data); return
  end

  -- Step 3 & 4: Apply balance changes atomically
  Balances[msg.From] = utils.subtract(Balances[msg.From], totalQuantity)
  for recipient, increaseAmount in pairs(balanceIncreases) do
      if not Balances[recipient] then Balances[recipient] = "0" end 
      Balances[recipient] = utils.add(Balances[recipient], increaseAmount)
  end

  -- Step 5: Send Batch-Debit-Notice
  local batchDebitNotice = { Action = 'Batch-Debit-Notice', Count = tostring(#transferEntries), Total = totalQuantity, ['Batch-Transfer-Init-Id'] = msg.Id, Data = "OK" }
  forwardXTags(msg, batchDebitNotice)
  msg.reply(batchDebitNotice)
  
  -- Step 6: Send Credit-Notices (if not Cast)
  if not msg.Cast then
    for _, entry in ipairs(transferEntries) do
      local creditNotice = { Target = entry.Recipient, Action = 'Credit-Notice', Sender = msg.From, Quantity = entry.Quantity, ['Batch-Transfer-Init-Id'] = msg.Id,
                           Data = Colors.gray .. "You received " .. Colors.blue .. entry.Quantity .. Colors.gray .. " from " .. Colors.green .. msg.From .. Colors.reset }
      forwardXTags(msg, creditNotice)
      Send(creditNotice)
    end
  end
end)

--[[ Mint ]]--
Handlers.add('mint', Handlers.utils.hasMatchingTag("Action","Mint"), function(msg)
  validateQuantity(msg.Quantity, "Mint")
  if not Balances[ao.id] then Balances[ao.id] = "0" end

  if msg.From == ao.id then
    Balances[msg.From] = utils.add(Balances[msg.From], msg.Quantity)
    TotalSupply = utils.add(TotalSupply, msg.Quantity)
    local data = { Data = Colors.gray .. "Successfully minted " .. Colors.blue .. msg.Quantity .. Colors.reset }
    sendResponse(msg, data)
  else
    local err_data = { Action = 'Mint-Error', ['Message-Id'] = msg.Id, Error = 'Only the Process Owner can mint new ' .. Ticker .. ' tokens!' }
    sendResponse(msg, err_data)
  end
end)

--[[ Total Supply ]]--
Handlers.add('totalSupply', Handlers.utils.hasMatchingTag("Action","Total-Supply"), function(msg)
  assert(msg.From ~= ao.id, 'Cannot call Total-Supply from the same process!')
  local data = { Action = 'Total-Supply', Data = TotalSupply, Ticker = Ticker }
  sendResponse(msg, data)
end)

--[[ Burn ]] --
Handlers.add('burn', Handlers.utils.hasMatchingTag("Action",'Burn'), function(msg)
  local quantity = msg.Tags.Quantity
  local context = "Burn"
  validateQuantity(quantity, context)
  
  if not Balances[msg.From] then Balances[msg.From] = "0" end
  local senderBalance = Balances[msg.From]
  assert(bint(quantity) <= bint(senderBalance), context .. ': Quantity exceeds balance.')

  Balances[msg.From] = utils.subtract(senderBalance, quantity)
  TotalSupply = utils.subtract(TotalSupply, quantity)
  
  local data = { Data = Colors.gray .. "Successfully burned " .. Colors.blue .. quantity .. Colors.reset }
  sendResponse(msg, data)
end)