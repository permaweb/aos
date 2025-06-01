local bint = require('.bint')(256)
local json = require('json')

--[[
  --Author: https://github.com/skyf0xx
  --Author: https://github.com/ALLiDoizCode
  This module implements the AO NFT Standard based on ERC-721 with royalty support.

  Features:
  - Inspired by ERC-721
  - Royalty support (EIP-2981 inspired)
  - Rich metadata with extensible data format
  - Creator monetization features

  Terms:
    Sender: the wallet or Process that sent the Message
    TokenId: unique identifier for each NFT
    Owner: current owner of a specific token
    Operator: address approved to manage all tokens of an owner
    Approved: address approved to manage a specific token
]]

--[[
  Utility functions for number handling and operations
]]
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
  end,
  -- Generate next token ID
  generateTokenId = function()
    NextTokenId = NextTokenId + 1
    return tostring(NextTokenId)
  end
}

--[[
  Initialize State Variables
  NFTs are non-fungible so we track individual token ownership
]]
Variant = "0.0.1"

-- Collection metadata
Name = Name or 'AO NFT Collection'
Symbol = Symbol or 'AONFT'
Description = Description or 'A non-fungible token collection on AO'
Logo = Logo or ''

-- Token tracking
Owners = Owners or {}       -- tokenId -> owner address
Balances = Balances or {}   -- owner -> count of tokens owned
Approved = Approved or {}   -- tokenId -> approved address to operate a single token for a single owner
Operators = Operators or {} -- owner -> operator (operate all tokens for a single eowner) -> boolean
Metadata = Metadata or {}   -- tokenId -> metadata object
Tokens = Tokens or {}       -- array of all minted token IDs
NextTokenId = NextTokenId or 0

-- Royalty support
DefaultRoyalty = DefaultRoyalty or { recipient = "", percentage = "0" }
TokenRoyalties = TokenRoyalties or {} -- tokenId -> royalty info

-- Total supply
TotalSupply = utils.toBalanceValue(#Tokens)

--[[
  Helper functions
]]
local function tokenExists(tokenId)
  --[[
  Note, we don't check Tokens[tokenId] here.
  A token exists only if is already minted/ belongs to someone and not burned
  ]] --
  return Owners[tokenId] ~= nil
end

local function isApprovedOrOwner(spender, tokenId)
  local owner = Owners[tokenId]
  if not owner then return false end

  return spender == owner or
      Approved[tokenId] == spender or
      (Operators[owner] and Operators[owner][spender])
end

local function clearApproval(tokenId)
  Approved[tokenId] = nil
end

local function addTokenToOwner(owner, tokenId)
  Balances[owner] = utils.add(Balances[owner] or "0", "1")
end

local function removeTokenFromOwner(owner, tokenId)
  Balances[owner] = utils.subtract(Balances[owner] or "0", "1")
end

local function getDecimalPlaces(number)
  local numberStr = tostring(number)
  local decimalPos = string.find(numberStr, '%.')
  if decimalPos then
    return string.len(string.sub(numberStr, decimalPos + 1))
  else
    return 0
  end
end

--[[
  Handler: Info
  Returns collection metadata only
]]
Handlers.add('info', Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
  msg.reply({
    Action = 'Info-Response',
    name = Name,
    symbol = Symbol,
    description = Description,
    logo = Logo,
    totalSupply = utils.toNumber(TotalSupply),
    Data = json.encode({
      version = Variant,
      standard = "AO-ERC721",
      royalty = DefaultRoyalty
    })
  })
end)

--[[
  Handler: Info
  Returns token-specific metadata
]]
Handlers.add('token-info', Handlers.utils.hasMatchingTag("Action", "Token-Info"), function(msg)
  local tokenId = msg.Tags['Token-Id']

  assert(tokenId, 'Token-Id is required!')
  assert(tokenExists(tokenId), 'Token does not exist!')

  local metadata = Metadata[tokenId] or {}

  msg.reply({
    Action = 'Token-Info-Response',
    -- Core required fields
    name = metadata.name or (Name .. " #" .. tokenId),
    symbol = Symbol,
    tokenId = tokenId,
    owner = Owners[tokenId],
    totalSupply = utils.toNumber(TotalSupply),
    description = metadata.description or Description,
    -- Extended data as JSON See recommendations at end of file, for metadata structure
    Data = json.encode(metadata.extendedData or {})
  })
end)

--[[
  Handler: Balance
  Returns number of tokens owned by an address
]]
Handlers.add('balance', Handlers.utils.hasMatchingTag("Action", "Balance"), function(msg)
  local target = msg.Tags.Target or msg.Tags.Recipient or msg.From
  local balance = Balances[target] or "0"

  msg.reply({
    Action = 'Balance-Response',
    Balance = balance,
    Account = target,
    Data = balance
  })
end)

--[[
  Handler: Owner-Of
  Returns the owner of a specific token
]]
Handlers.add('owner-of', Handlers.utils.hasMatchingTag("Action", "Owner-Of"), function(msg)
  local tokenId = msg.Tags['Token-Id']
  assert(tokenId, 'Token-Id is required!')
  assert(tokenExists(tokenId), 'Token does not exist!')

  msg.reply({
    Action = 'Owner-Of-Response',
    TokenId = tokenId,
    Owner = Owners[tokenId],
    Data = Owners[tokenId]
  })
end)

--[[
  Handler: Transfer
  Transfers a token from sender to recipient
]]
Handlers.add('transfer', Handlers.utils.hasMatchingTag("Action", "Transfer"), function(msg)
  local tokenId = msg.Tags['Token-Id']
  local recipient = msg.Tags.Recipient

  assert(tokenId, 'Token-Id is required!')
  assert(recipient, 'Recipient is required!')
  assert(tokenExists(tokenId), 'Token does not exist!')
  assert(isApprovedOrOwner(msg.From, tokenId), 'Not authorized to transfer this token!')
  assert(recipient ~= "", 'Invalid recipient address!')

  local owner = Owners[tokenId]

  -- Clear approval
  clearApproval(tokenId)

  -- Update balances
  removeTokenFromOwner(owner, tokenId)
  addTokenToOwner(recipient, tokenId)

  -- Update ownership
  Owners[tokenId] = recipient

  --[[
    Only send the notifications to the Sender and Recipient
    if the Cast tag is not set on the Transfer message
  ]]
  if not msg.Cast then
    local debitNotice = {
      Target = owner,
      Action = 'NFT-Debit-Notice',
      Recipient = recipient,
      ['Token-Id'] = tokenId,
      Data = Colors.gray ..
          "You transferred NFT " ..
          Colors.blue .. tokenId .. Colors.gray .. " to " .. Colors.green .. recipient .. Colors.reset
    }

    local creditNotice = {
      Target = recipient,
      Action = 'NFT-Credit-Notice',
      Sender = owner,
      ['Token-Id'] = tokenId,
      Data = Colors.gray ..
          "You received NFT " ..
          Colors.blue .. tokenId .. Colors.gray .. " from " .. Colors.green .. owner .. Colors.reset
    }

    -- Add forwarded tags to the credit and debit notice messages
    for tagName, tagValue in pairs(msg.Tags) do
      -- Tags beginning with "X-" are forwarded
      if string.sub(tagName, 1, 2) == "X-" then
        debitNotice[tagName] = tagValue
        creditNotice[tagName] = tagValue
      end
    end

    ao.send(debitNotice)
    ao.send(creditNotice)

    if msg.From ~= owner then
      -- Send a confirmation message to the operator
      debitNotice.Action = 'NFT-Debit-Notice-CC'
      debitNotice.Target = msg.From
      ao.send(debitNotice)
    end
  end
end)

--[[
  Handler: Approve
  Approve an address to transfer a specific token
  E.g. marketplace to handle one token
  Also use to revoke approval by setting approved not "true"
]]
Handlers.add('approve', Handlers.utils.hasMatchingTag("Action", "Approve"), function(msg)
  local tokenId = msg.Tags['Token-Id']
  local spender = msg.Tags.Spender
  local approved = msg.Tags.Approved == "true"

  assert(tokenId, 'Token-Id is required!')
  assert(spender, 'Spender is required!')
  assert(tokenExists(tokenId), 'Token does not exist!')

  local owner = Owners[tokenId]
  assert(msg.From == owner or (Operators[owner] and Operators[owner][msg.From]),
    'Not authorized to approve this token!')
  assert(spender ~= owner, 'Cannot approve token owner!')

  if approved then
    Approved[tokenId] = spender
  else
    Approved[tokenId] = nil --revoke
  end

  msg.reply({
    Action = 'Approve-Response',
    TokenId = tokenId,
    Spender = spender,
    Approved = tostring(approved),
    Data = Colors.gray .. (approved and "Approved " or "Revoked approval for ") ..
        Colors.green .. spender .. Colors.gray .. " for token " .. Colors.blue .. tokenId .. Colors.reset
  })

  -- Send notice to the spender
  local approvalNotice = {
    Target = spender,
    Action = approved and 'Approval-Notice' or 'Approval-Revoked-Notice',
    Owner = owner,
    ['Token-Id'] = tokenId,
    Approved = tostring(approved),
    Data = Colors.gray .. "Approval for NFT " .. Colors.blue .. tokenId ..
        Colors.gray .. " was " .. (approved and "granted" or "revoked") ..
        " by " .. Colors.green .. owner .. Colors.reset
  }
  ao.send(approvalNotice)

  if msg.From ~= owner then
    -- Send a confirmation message to the owner
    approvalNotice.Target = owner
    ao.send(approvalNotice)
  end
end)

--[[
  Handler: Approve-All
  Approve an operator for all tokens - ie add an Operator for the Owner
  E.g. marketplace to handle entire collection for the owner
  Also use to revoke approval by setting approved not "true"
]]
Handlers.add('approve-all', Handlers.utils.hasMatchingTag("Action", "Approve-All"), function(msg)
  local operator = msg.Tags.Operator
  local approved = msg.Tags.Approved == "true"

  assert(operator, 'Operator is required!')
  assert(operator ~= msg.From, 'Cannot approve yourself as operator!')

  Operators[msg.From] = Operators[msg.From] or {}
  Operators[msg.From][operator] = approved or nil

  msg.reply({
    Action = 'Approve-All-Response',
    Operator = operator,
    Approved = tostring(approved),
    Data = Colors.gray .. (approved and "Approved " or "Revoked approval for ") ..
        Colors.green .. operator .. Colors.gray .. " as operator" .. Colors.reset
  })
end)

--[[
  Handler: Get-Approved
  Get the approved address for a token
]]
Handlers.add('get-approved', Handlers.utils.hasMatchingTag("Action", "Get-Approved"), function(msg)
  local tokenId = msg.Tags['Token-Id']

  assert(tokenId, 'Token-Id is required!')
  assert(tokenExists(tokenId), 'Token does not exist!')

  local approved = Approved[tokenId] or ""

  msg.reply({
    Action = 'Get-Approved-Response',
    TokenId = tokenId,
    Approved = approved,
    Data = approved
  })
end)

--[[
  Handler: Is-Approved-For-All
  Check if an operator is approved for all tokens
]]
Handlers.add('is-approved-for-all', Handlers.utils.hasMatchingTag("Action", "Is-Approved-For-All"), function(msg)
  local owner = msg.Tags.Owner
  local operator = msg.Tags.Operator

  assert(owner, 'Owner is required!')
  assert(operator, 'Operator is required!')

  local approved = Operators[owner] and Operators[owner][operator] or false

  msg.reply({
    Action = 'Is-Approved-For-All-Response',
    Owner = owner,
    Operator = operator,
    Approved = tostring(approved),
    Data = tostring(approved)
  })
end)

--[[
  Handler: Total-Supply
  Returns total number of minted tokens
]]
Handlers.add('total-supply', Handlers.utils.hasMatchingTag("Action", "Total-Supply"), function(msg)
  msg.reply({
    Action = 'Total-Supply-Response',
    TotalSupply = utils.toNumber(TotalSupply),
    Data = TotalSupply
  })
end)

--[[
  Handler: Token-By-Index
  Get token ID by global index
]]
Handlers.add('token-by-index', Handlers.utils.hasMatchingTag("Action", "Token-By-Index"), function(msg)
  local index = tonumber(msg.Tags.Index)

  assert(index, 'Index is required!')
  assert(index >= 1 and index <= #Tokens, 'Index out of bounds!')

  local tokenId = Tokens[index]

  msg.reply({
    Action = 'Token-By-Index-Response',
    Index = tostring(index),
    TokenId = tokenId,
    Data = tokenId
  })
end)

--[[
  Handler: Tokens-Of-Owner
  Get all token IDs owned by an address
]]
Handlers.add('tokens-of-owner', Handlers.utils.hasMatchingTag("Action", "Tokens-Of-Owner"), function(msg)
  local owner = msg.Tags.Owner or msg.From
  local ownedTokens = {}

  for _, tokenId in ipairs(Tokens) do
    if Owners[tokenId] == owner then
      table.insert(ownedTokens, tokenId)
    end
  end

  msg.reply({
    Action = 'Tokens-Of-Owner-Response',
    Owner = owner,
    TokenIds = ownedTokens,
    Count = tostring(#ownedTokens),
    Data = json.encode(ownedTokens)
  })
end)

--[[
  Handler: Mint
  Mint new NFT to specified address
]]
Handlers.add('mint', Handlers.utils.hasMatchingTag("Action", "Mint"), function(msg)
  local recipient = msg.Tags.Recipient or msg.From
  local tokenId = msg.Tags['Token-Id'] or utils.generateTokenId()
  local metadata = {}

  -- Only allow minting by process owner (can be extended with custom logic)
  assert(msg.From == ao.id, 'Only the process owner can mint tokens!')
  assert(not tokenExists(tokenId), 'Token already exists!')
  assert(recipient ~= "", 'Invalid recipient address!')

  -- Parse metadata if provided
  if msg.Tags.Name then metadata.name = msg.Tags.Name end
  if msg.Tags.Description then metadata.description = msg.Tags.Description end
  if msg.Tags.Image then metadata.image = msg.Tags.Image end
  if msg.Tags.ExternalUrl then metadata.externalUrl = msg.Tags.ExternalUrl end
  if msg.Tags.Attributes then
    metadata.attributes = json.decode(msg.Tags.Attributes) or {}
  end

  -- Store extended data if provided
  if msg.Tags.ExtendedData then
    metadata.extendedData = json.decode(msg.Tags.ExtendedData) or {}
  end

  -- Mint the token
  Owners[tokenId] = recipient
  Metadata[tokenId] = metadata
  addTokenToOwner(recipient, tokenId)
  table.insert(Tokens, tokenId)
  TotalSupply = utils.add(TotalSupply, "1")

  msg.reply({
    Action = 'Mint-Response',
    TokenId = tokenId,
    Recipient = recipient,
    Data = Colors.gray .. "Successfully minted token " .. Colors.blue .. tokenId ..
        Colors.gray .. " to " .. Colors.green .. recipient .. Colors.reset
  })

  -- Send mint notice to recipient if different from sender
  if recipient ~= msg.From then
    ao.send({
      Target = recipient,
      Action = 'Mint-Notice',
      TokenId = tokenId,
      Data = Colors.gray .. "You received NFT " .. Colors.blue .. tokenId .. Colors.reset
    })
  end
end)

--[[
  Handler: Burn
  Burn/destroy an existing token
]]
Handlers.add('burn', Handlers.utils.hasMatchingTag("Action", "Burn"), function(msg)
  local tokenId = msg.Tags['Token-Id']

  assert(tokenId, 'Token-Id is required!')
  assert(tokenExists(tokenId), 'Token does not exist!')
  assert(isApprovedOrOwner(msg.From, tokenId), 'Not authorized to burn this token!')

  local owner = Owners[tokenId]

  -- Clear approvals
  clearApproval(tokenId)

  -- Remove from owner
  removeTokenFromOwner(owner, tokenId)

  -- Remove from global tracking
  Owners[tokenId] = nil
  Metadata[tokenId] = nil
  TokenRoyalties[tokenId] = nil

  -- Remove from Tokens array
  for i, id in ipairs(Tokens) do
    if id == tokenId then
      table.remove(Tokens, i)
      break
    end
  end

  TotalSupply = utils.subtract(TotalSupply, "1")

  msg.reply({
    Action = 'Burn-Response',
    TokenId = tokenId,
    Data = Colors.gray .. "Successfully burned token " .. Colors.blue .. tokenId .. Colors.reset
  })
end)

--[[
  Handler: Royalty-Info
  Get royalty information for a token sale
]]
Handlers.add('royalty-info', Handlers.utils.hasMatchingTag("Action", "Royalty-Info"), function(msg)
  local tokenId = msg.Tags['Token-Id']
  local salePrice = msg.Tags['Sale-Price']

  assert(tokenId, 'Token-Id is required!')
  assert(salePrice, 'Sale-Price is required!')
  assert(tokenExists(tokenId), 'Token does not exist!')
  assert(tonumber(salePrice), 'Sale-Price must be a valid number!')
  assert(tonumber(salePrice) > 0, 'Sale-Price must be greater than 0!')

  local royalty = TokenRoyalties[tokenId] or DefaultRoyalty
  local royaltyAmount = "0"

  -- Convert percentage from string to bint directly
  local percentageBint = bint(royalty.percentage or "0")

  if bint.__lt(bint("0"), percentageBint) and royalty.recipient ~= "" then
    local basisPoints = percentageBint * bint("100")
    local salePriceBint = bint(salePrice)
    local divisor = bint("10000") -- 10000 basis points = 100%

    local amount = (salePriceBint * basisPoints) / divisor
    royaltyAmount = tostring(amount)
  end

  msg.reply({
    Action = 'Royalty-Info-Response',
    TokenId = tokenId,
    SalePrice = salePrice,
    RoyaltyRecipient = royalty.recipient,
    RoyaltyAmount = royaltyAmount,
    RoyaltyPercentage = royalty.percentage,
    Data = json.encode({
      recipient = royalty.recipient,
      amount = royaltyAmount,
      percentage = royalty.percentage
    })
  })
end)

--[[
  Handler: Set-Royalty
  Set royalty information for tokens
]]
Handlers.add('set-royalty', Handlers.utils.hasMatchingTag("Action", "Set-Royalty"), function(msg)
  local tokenId = msg.Tags['Token-Id']
  local recipient = msg.Tags.Recipient
  local percentage = msg.Tags.Percentage

  assert(msg.From == ao.id, 'Only process owner can set royalty!')
  assert(recipient, 'Recipient is required!')
  assert(percentage, 'Percentage is required!')

  -- Validate percentage is a valid number
  local percentageNum = tonumber(percentage)
  assert(percentageNum, 'Percentage must be a valid number!')
  assert(percentageNum >= 0 and percentageNum <= 100, 'Percentage must be between 0 and 100!')
  assert(getDecimalPlaces(percentageNum) <= 4, 'Percentage can have at most 4 decimal places (e.g., 2.5000)!')

  -- Store percentage as string for consistency with royalty-info handler
  if tokenId then
    assert(tokenExists(tokenId), 'Token does not exist!')
    TokenRoyalties[tokenId] = {
      recipient = recipient,
      percentage = percentage
    }
  else
    DefaultRoyalty = {
      recipient = recipient,
      percentage = percentage
    }
  end

  msg.reply({
    Action = 'Set-Royalty-Response',
    TokenId = tokenId or "default",
    Recipient = recipient,
    Percentage = percentage, -- Return as string
    Data = Colors.gray .. "Royalty set to " .. Colors.blue .. percentage .. "%" ..
        Colors.gray .. " for " .. Colors.green .. recipient .. Colors.reset
  })
end)

--[[
  Handler: Default-Royalty
  Get default royalty information
]]
Handlers.add('default-royalty', Handlers.utils.hasMatchingTag("Action", "Default-Royalty"), function(msg)
  msg.reply({
    Action = 'Default-Royalty-Response',
    Recipient = DefaultRoyalty.recipient,
    Percentage = DefaultRoyalty.percentage,
    Data = json.encode(DefaultRoyalty)
  })
end)

--[[
  Handler: Exists
  Check if a token exists
]]
Handlers.add('exists', Handlers.utils.hasMatchingTag("Action", "Exists"), function(msg)
  local tokenId = msg.Tags['Token-Id']

  assert(tokenId, 'Token-Id is required!')

  local exists = tokenExists(tokenId)

  msg.reply({
    Action = 'Exists-Response',
    TokenId = tokenId,
    Exists = tostring(exists),
    Data = tostring(exists)
  })
end)

--[[
  Handler: Balances
  Get all balances for debugging/enumeration
]]
Handlers.add('balances', Handlers.utils.hasMatchingTag("Action", "Balances"), function(msg)
  msg.reply({
    Action = 'Balances-Response',
    Data = json.encode(Balances)
  })
end)



--[[
 Extended Data JSON Structure - Recommended Format

 Standard Fields (SHOULD HAVE):
 {
   "image": "arweave-tx-id-for-image",
   "externalUrl": "https://mygame.com/item/12345",
   "maxSupply": 10000,
   "attributes": [
     {
       "traitType": "Rarity",
       "value": "Legendary",
       "displayType": "string"
     },
     {
       "traitType": "Attack Power",
       "value": 95,
       "displayType": "number"
     }
   ]
 }

 Namespaced Extensions (MAY HAVE):

 Gaming Extensions:
 "gaming.stats": { "level": 15, "experience": 1250, "health": 100 }
 "gaming.items": { "equipment": ["sword", "shield"], "inventory": 50 }
 "gaming.achievements": { "unlocked": ["first_kill", "level_10"], "progress": {...} }

 Financial Extensions:
 "finance.defi": { "stakingRewards": "1000.50", "poolShare": "0.05", "yieldRate": "12.5%" }
 "finance.payments": { "price": "100.00", "currency": "AR", "marketplace": "atomicassets" }

 Social Extensions:
 "social.reputation": { "score": 850, "endorsements": 42, "communityRank": "Gold" }
 "social.relationships": { "followers": 150, "following": 75, "friends": ["addr1", "addr2"] }

 Utility Extensions:
 "utility.access": { "permissions": ["read", "write"], "subscriptionTier": "premium", "expirationTime": 1672531200 }
 "utility.membership": { "tier": "gold", "benefits": ["discount", "priority"], "renewalDate": "2024-12-31" }

 Physical World Extensions:
 "physical.location": { "coordinates": [lat, lng], "address": "123 Main St", "venue": "Gallery XYZ" }
 "physical.iot": { "deviceId": "sensor123", "lastReading": 25.6, "batteryLevel": 85 }

 Temporal Extensions:
 "temporal.dynamic": { "lastUpdated": 1640995200, "updateFrequency": "daily", "volatility": "high" }
 "temporal.lifecycle": { "createdAt": 1640995200, "maturityDate": 1672531200, "phase": "active" }

 Custom Project Extensions:
 "myproject.custom": { "specialFeature": "value", "projectSpecific": true }
]]
