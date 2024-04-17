--[[
  ao20 Token Module - v0.1.0 - 17/Apr/2024
  Puente.ai - michael@puente.ai
  https://github.com/puente-ai/ao-modules/blob/main/src/blueprints/modules/token/ao20.lua

  This module implements the base module for core ao20 Token functionality.

  References: 
    - ao Standard Token Specification: https://cookbook_ao.arweave.dev/guides/aos/blueprints/token.html
    - ERC20 Token Standard: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol
]]
--

local ao = require('ao')
local json = require('json')
local utils = require('.utils')
local bint = require('.bint')(256)

local initialized = false
local ao20 = {
  _version = "0.1.0",
  Balances = {},
  Allowances = {},
  Name = "",
  Ticker = "",
  Denomination = 1,
  Logo = "",
  Owner = ao.id,
  Burnable = false,
  Mintable = false,
  Pausable = false,
  Paused = false,
  Initialized = initialized
}

--[[
     Local functions, only accessible from within the module
   ]]
--

--[[
    Total Supply
   ]]
-- 
-- @dev Returns the quantity of tokens in existence.
local function _totalSupply()
  local res = utils.reduce(
    function (acc, v) return acc + v end,
    0,
    bint(utils.values(ao20.Balances))
  )
  -- Convert to string without e+ formatting
  return string.format("%.i",res)
end

--[[
     Approve
   ]]
--
-- @dev Sets `quantity` as the allowance of `spender` over the `sender` s tokens.
-- Sends {Approve-Notice} and {Approval-Notice} Messages when `boolean sendNotice` is true. 
local function _approve(sender, spender, quantity, sendNotice)
  assert(type(spender) == 'string', 'Spender is required!')
  assert(type(quantity) == 'string', 'Quantity is required!')
  assert(bint.__le(0, quantity), 'Quantity must be greater than or equal to zero!')

  if not ao20.Allowances[sender] then ao20.Allowances[sender] = {} end
  if not ao20.Allowances[sender][spender] then ao20.Allowances[sender][spender] = '0' end

  ao20.Allowances[sender][spender] = quantity

  if sendNotice then
    -- Send Approve-Notice to the Sender
    ao.send({
      Target = sender,
      Action = 'Approve-Notice',
      Spender = spender,
      Allowance = quantity,
      Data = "You granted an allowance of " .. quantity .. " to " .. spender
    })
    -- Send Approval-Notice to the Spender
    ao.send({
      Target = spender,
      Action = 'Approval-Notice',
      Sender = sender,
      Allowance = quantity,
      Data = "You received an allowance of " .. quantity .. " from " .. sender
    })
  end
end

--[[
    Spend Allowance
   ]]
--
-- @dev Variant of {_approve} with an optional flag to enable or disable {Approve-Notice} and {Approval-Notice} Messages.
local function _spendAllowance(sender, spender, quantity, id)
  if not ao20.Allowances[sender] then ao20.Allowances[sender] = {} end
  if not ao20.Allowances[sender][spender] then ao20.Allowances[sender][spender] = '0' end

  local allowance = ao20.Allowances[sender][spender]

  -- Revert on Insufficient Allowance
    if not bint.__le(quantity, allowance) then
      ao.send({
        Target = spender,
        Action = 'Transfer-Error',
        ['Message-Id'] = id,
        Error = 'Insufficient Allowance!'
      })
      assert(false, 'Quantity must be less than or equal to allowance!')
    end

  -- decrease allowance without sending notice
  _approve(sender, spender, tostring(bint.__sub(allowance, quantity)), false)
end

--[[
    Update
   ]]
--
-- @dev Transfers a `msg.Quantity` amount of tokens from `sender` to `recipient`,
-- or alternatively mints if `sender` is `nil` or burns if `recipient` is `nil`.
-- All customizations to transfers, mints, and burns should be done by overriding this function.
-- Sends {Debit-Notice} and {Credit-Notice} Messages when targets are not `nil`,
-- and the {Transfer-Notice} Message when the `sender` is the same as the `spender`.
local function _update(msg)
  assert(not ao20.Paused, 'Contract is paused!')
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint.__lt(0, msg.Quantity), 'Quantity must be greater than zero!')

  local qty = bint(msg.Quantity)
  local sender = type(msg.Sender) == 'string' and msg.Sender or msg.From

  local spender = msg.From
  local recipient = type(msg.Recipient) == 'string' and msg.Recipient or msg.From

  if not ao20.Balances[sender] then ao20.Balances[sender] = "0" end
  if not ao20.Balances[recipient] then ao20.Balances[recipient] = "0" end

  if msg.Action == 'Mint' then
    -- Set sender to nil to avoid debit notice
    sender = nil
    -- If a Recipient is not provided, tokens are minted to the Processes' balance
    recipient = type(msg.Recipient) == 'string' and recipient or ao.id
    -- Add tokens to the recipient balance, according to Quantity
    ao20.Balances[recipient] = tostring(bint.__add(ao20.Balances[recipient], qty))
  elseif (msg.Action == 'Burn' or msg.Action == 'BurnFrom') then
    -- Set recipient to nil to avoid credit notice
    recipient = nil
    -- Revert if overflow
    local totalSupply = _totalSupply()
    if not bint.__le(qty, totalSupply) then
      ao.send({
        Target = msg.From,
        Action = 'Burn-Error',
        ['Message-Id'] = msg.Id,
        Error = 'Overflow!'
      })
      assert(false, 'Total Supply must be greater than quantity!')
    end
    -- Revert on Insufficient Balance
    if not bint.__le(qty, bint(ao20.Balances[sender])) then
      ao.send({
        Target = msg.From,
        Action = 'Burn-Error',
        ['Message-Id'] = msg.Id,
        Error = 'Insufficient Balance!'
      })
      assert(false, 'Balance must be greater than quantity!')
    end
    --  decrease spender's allowance (burnFrom)
    if (sender ~= spender) then
      _spendAllowance(sender, spender, qty, msg.id)
    end
      -- Burn tokens from the Sender balance, according to Quantity
    ao20.Balances[sender] = tostring(bint.__sub(ao20.Balances[sender], qty))
  else
    if (sender ~= spender) then
      -- decrease spender's allowance (transferFrom)
      _spendAllowance(sender, spender, qty, msg.id)
    else
      -- decreate recipient's allowance (transfer)
      _spendAllowance(sender, recipient, qty, msg.id)
    end
    -- Transfer tokens from target to recipient, according to Quantity
    local balance = ao20.Balances[sender]
    if bint.__le(qty, balance) then
      ao20.Balances[sender] = tostring(bint.__sub(balance, qty))
      ao20.Balances[recipient] = tostring(bint.__add(ao20.Balances[recipient], qty))
    else
      ao.send({
        Target = msg.From,
        Action = 'Transfer-Error',
        ['Message-Id'] = msg.Id,
        Error = 'Insufficient Balance!'
      })
      assert(false, 'Quantity must be less than or equal to balance! ' .. tostring(qty) .. ' ' .. tostring(balance))
    end
  end

  if not msg.Cast then
    -- Send Debit-Notice to the Sender if not Mint
    if sender ~= nil then
      ao.send({
        Target = sender,
        Action = 'Debit-Notice',
        Spender = tostring(spender),
        Recipient = tostring(recipient),
        Quantity = tostring(qty),
        Data =  "You transferred " .. msg.Quantity .. " to " .. tostring(recipient) .. " initiated by " .. tostring(spender)
      })
    end

    -- Send Credit-Notice to the Recipient if not Burn
    if recipient ~= nil then
      ao.send({
        Target = recipient,
        Action = 'Credit-Notice',
        Spender = tostring(spender),
        Sender = tostring(sender),
        Quantity = tostring(qty),
        Data = "You received " .. msg.Quantity .. " from " .. tostring(sender) .. " initiated by " .. tostring(spender)
      })
    end
    -- Send Transfer-Notice to the Sender if not the Spender
    if sender ~= spender then
      ao.send({
        Target = spender,
        Action = 'Transfer-Notice',
        Spender = tostring(spender),
        Sender = tostring(sender),
        Recipient = tostring(recipient),
        Quantity = tostring(qty),
        Data =  "You initiated the transfer of " .. msg.Quantity .. " from " .. tostring(sender) .. " to " .. tostring(recipient)
      })
    end
  end
end

--[[
    Transfer
   ]]
--
-- @dev Moves a `msg.Quantity` amount of tokens from `msg.From` to `msg.Recipient`.
-- Relies on the `_update` mechanism.
local function _transfer(msg)
  assert(type(msg.Recipient) == 'string', 'Recipient is required!')
  _update(msg)
end

--[[
    Mint
   ]]
--
-- @dev Creates a `msg.Quantity` amount of tokens and assigns them to `msg.Recipient`, by transferring it from `nil`.
-- @notice This diverges from the ERC20 standard where the recipient must be the contract itself.
-- Relies on the `_update` mechanism.
local function _mint(msg)
  assert(ao20.Mintable, 'Minting is not allowed!')
  assert(msg.From == ao20.Owner, 'Sender must be Owner!')
  _update(msg)
end

--[[
     Burn
   ]]
--
-- @dev Destroys a `msg.Quantity` amount of tokens from `msg.From`, lowering the total supply.
-- Relies on the `_update` mechanism.
local function _burn(msg)
  assert(ao20.Burnable, 'Burning is not allowed!')
  assert(msg.From == ao20.Owner, 'Sender must be Owner!')
  _update(msg)
end

--[[
     Burn From
   ]]
--
-- @dev Destroys a `msg.Quantity` amount of tokens from `msg.Sender`, deducting from the `msg.From` allowance, 
-- lowering the total supply.
-- @notice This diverges from the ERC20 standard where only `_burn` is implemented.
-- Relies on the `_update` mechanism.
local function _burnFrom(msg)
  assert(ao20.Burnable, 'Burning is not allowed!')
  assert(msg.From == ao20.Owner, 'Sender must be Owner!')
  _update(msg)
end

--[[
    Pause
   ]]
--
-- @dev Pauses the contract, preventing any `_update` functionality.
-- Sends a {Pause-Notice} Message to the Sender.
local function _pause(msg)
  assert(msg.From == ao20.Owner, 'Sender must be Owner!')
  assert(ao20.Pausable, 'Pausing is not allowed!')
  assert(type(msg.Tags.Paused) == 'string', 'Paused Tag is required!')
  local isPaused = json.decode(msg.Tags.Paused)
  assert(type(isPaused) == 'boolean', 'Pause Tag must be a boolean!')
  ao20.Paused = isPaused

  -- Send Pause-Notice to the Sender
  ao.send({
    Target = msg.From,
    Action = 'Pause-Notice',
    Process = ao.id,
    Paused = json.encode(ao20.Paused ),
    Data = "Process " .. ao.id .. " paused status set to " .. msg.Tags.Paused
  })
end

--[[
    Renounce Ownership
   ]]
--
-- @dev Renounces ownership of the Process, setting `ao20.Owner` to nil.
-- Sends a {Renounce-Ownership-Notice} Message to the Sender.
local function _renounceOwnership(msg)
  assert(msg.From == ao20.Owner, 'Sender must be Owner!')
  ao20.Owner = nil

  -- Send Renounce-Ownership-Notice to the Sender
  ao.send({
    Target = msg.From,
    Action = 'Renounce-Ownership-Notice',
    Process = ao.id,
    Owner = tostring(ao20.Owner),
    Data = "Process " .. ao.id .. " ownership has been renounced"
  })
end

--[[
    Transfer Ownership
   ]]
--
-- @dev Transfers ownership of the Process, setting ào20.Owner` to the `msg.NewOwner` wallet or Process.
-- Sends a {Transfer-Ownership-Notice} Message to the Sender and a {New-Ownership-Notice} Message to the New Owner.
local function _transferOwnership(msg)
  assert(msg.From == ao20.Owner, 'Sender must be Owner!')
  assert(type(msg.Tags.NewOwner) == 'string', 'NewOwner Tag is required!')
  assert(#msg.Tags.NewOwner > 0, 'NewOwner Tag must exist!')
  ao20.Owner = msg.Tags.NewOwner

  -- Send Transfer-Ownership-Notice to the Sender
  ao.send({
    Target = msg.From,
    Action = 'Transfer-Ownership-Notice',
    Process = ao.id,
    Owner = tostring(ao20.Owner),
    Data = "You transferred ownership of " .. ao.id .. " to " .. tostring(ao20.Owner)
  })

  -- Send New-Ownership-Notice to the New Owner
  ao.send({
    Target = ao20.Owner,
    Action = 'New-Ownership-Notice',
    Process = ao.id,
    Data = "You received ownership of " .. ao.id .. " from " .. msg.From
  })
end

--[[
    Protected function - can only be run once
   ]]
-- 

--[[
    Constructor
   ]]
-- 
-- @dev Sets the initial state of the Process. 
-- @notice This function can only be called once.
function ao20.constructor(params)
  assert(not initialized, "Already initialized!")

  -- parse input parameters
  params = params and params or {}
  local options = {
    balances = "Balances",
    name = "Name",
    ticker = "Ticker",
    denomination = "Denomination",
    logo = "Logo",
    burnable = "Burnable",
    mintable = "Mintable",
    pausable = "Pausable",
    paused = "Paused",
    owner = "Owner"
  }

  for k,v in pairs(params) do options[k] = v end

  -- initialize config 
  ao20.Balances = options.balances and options.balances or {}
  ao20.Name = options.name and options.name or ''
  ao20.Ticker = options.ticker and options.ticker or ''
  ao20.Denomination = options.denomination and options.denomination or ''
  ao20.Logo = options.logo and options.logo or ''
  ao20.Burnable = options.burnable and options.burnable or false
  ao20.Mintable = options.mintable and options.mintable or false
  ao20.Pausable = options.pausable and options.pausable or false
  ao20.Paused = options.paused and options.paused or false

  -- set owner
  ao20.Owner = options.owner and options.owner or ao.id

  -- set as initialized
  initialized = true
  ao20.Initialized = initialized
end

--[[
     Public functions for each incoming Action as defined by the ao20 Token Specification
   ]]
--

--[[
     Info
   ]]
--
-- @dev Returns the info about the token.
function ao20.info(msg)
  ao.send({
    Target = msg.From,
    Name = ao20.Name,
    Ticker = ao20.Ticker,
    Denomination = tostring(ao20.Denomination),
    Logo = ao20.Logo,
    Initializable = tostring(ao20.Initializable),
    Burnable = tostring(ao20.Burnable),
    Mintable = tostring(ao20.Mintable),
    Pausable = tostring(ao20.Pausable),
    Paused = tostring(ao20.Paused),
    Owner = tostring(ao20.Owner),
  })
end

--[[
     Total Supply
   ]]
--
-- @dev Returns the quantity of tokens in existence.
function ao20.totalSupply(msg)
  local totalSupply = _totalSupply()
  ao.send({
    Target = msg.From,
    TotalSupply = tostring(totalSupply),
    Data = totalSupply
  })
end

--[[
     Balance
   ]]
--
-- @dev Returns the quantity of tokens owned by `msg.From` or `msg.Target`, if provided.
function ao20.balance(msg)
  local bal = '0'

  -- If not Target is provided, then return the Senders balance
  if (msg.Tags.Target and ao20.Balances[msg.Tags.Target]) then
    bal = ao20.Balances[msg.Tags.Target]
  elseif ao20.Balances[msg.From] then
    bal = ao20.Balances[msg.From]
  end

  ao.send({
    Target = msg.From,
    Balance = bal,
    Ticker = ao20.Ticker,
    Account = msg.Tags.Target or msg.From,
    Data = bal
  })
end

--[[
     Balances
   ]]
--
-- @dev Returns the quantity of tokens owned by all participants.
function ao20.balances(msg)
  ao.send({ Target = msg.From, Data = json.encode(ao20.Balances) })
end

--[[
     Transfer
   ]]
--
-- @dev Moves a `msg.Quantity` amount of tokens from the caller `msg.From` wallet or Process to `msg.Recipient`.
function ao20.transfer(msg)
  _transfer(msg)
end

--[[
     Allowance
   ]]
--
-- @dev Returns the quantity of tokens that `msg.Spender` is allowed to spend on behalf of `msg.From` or `msg.Target`, if provided.
function ao20.allowance(msg)
  assert(type(msg.Spender) == 'string', 'Spender is required!')
  local allowance = '0'

  -- If not Target is provided, then return the Senders allowance for a given Spender
  if (msg.Tags.Target and ao20.Allowances[msg.Tags.Target] and ao20.Allowances[msg.Tags.Target][msg.Spender]) then
    allowance = ao20.Allowances[msg.Tags.Target][msg.Spender]
  elseif ao20.Allowances[msg.From] and ao20.Allowances[msg.From][msg.Spender] then
    allowance = ao20.Allowances[msg.From][msg.Spender]
  end

  ao.send({
    Target = msg.From,
    Allowance = allowance,
    Spender = msg.Spender,
    Ticker = ao20.Ticker,
    Account = msg.Tags.Target or msg.From,
    Data = allowance
  })
end

--[[
     Allowances
   ]]
--
-- @dev Returns the quantity of tokens that all participants are allowed to spend on behalf of the Senders.
function ao20.allowances(msg)
  ao.send({ Target = msg.From, Data = json.encode(ao20.Allowances) })
end

--[[
     Approve
   ]]
--
-- @dev Sets the `msg.Quantity` amount of allowance the `spender` has over the `sender` s tokens.
function ao20.approve(msg)
  _approve(msg.From, msg.Spender, msg.Quantity, true)
end

--[[
     Transfer From
   ]]
--
-- @dev Moves a `msg.Quantity` amount of tokens from `msg.Sender` to `msg.Recipient` using the allowance mechanism.
-- `msg.Quantity` is then deducted from the `msg.From` allowance.
function ao20.transferFrom(msg)
  assert(type(msg.Sender) == 'string', 'Sender is required!')
  _transfer(msg)
end

--[[
    Optional extensions enabled on initialization
  ]]
--

--[[
    Mint
   ]]
--
-- @dev Creates a `msg.Quantity` amount of tokens and assigns them to `msg.Recipient`, by transferring it from `nil`.
function ao20.mint(msg)
  _mint(msg)
end

--[[
    Burn
   ]]
--
-- @dev Destroys a `msg.Quantity` amount of tokens from `msg.From` to `nil`, lowering the total supply.
function ao20.burn(msg)
  _burn(msg)
end

--[[
    Burn From
   ]]
--
-- @dev Destroys a `msg.Quantity` amount of tokens from `msg.Sender` to `nil`, deducting from the `msg.From` allowance,
-- lowering the total supply.
function ao20.burnFrom(msg)
  assert(type(msg.Sender) == 'string', 'Sender is required!')
  _burnFrom(msg)
end

--[[
    Access Control following the Ownable control mechanism
  ]]
--

--[[
    Pause
   ]]
--
-- @dev Pauses the contract, preventing any `_update` functionality.
function ao20.pause(msg)
  _pause(msg)
end

--[[
    Renounce Ownership
   ]]
--
-- @dev Renounces ownership of the Process, setting `ao20.Owner` to nil.
function ao20.renounceOwnership(msg)
  _renounceOwnership(msg)
end

--[[
    Transfer Ownership
   ]]
--
-- @dev Transfers ownership of the Process, setting `ao20.Owner` to the `msg.NewOwner` wallet or Process.
function ao20.transferOwnership(msg)
  _transferOwnership(msg)
end

return ao20