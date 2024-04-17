--[[
  ao20 Token Specification - v0.1.0 - 17/Apr/2024
  Puente.ai - michael@puente.ai
  https://github.com/puente-ai/aos/blob/main/blueprints/ao20.lua  
  
  This module implements the ao20 Token Specification.

  Terms:
    Sender: the wallet or Process that sends a Message in a two-party transaction
    Spender: the wallet or Process that sends a Messages in a three-party transaction
    Recipient: the wallet or Process that receives tokens from a transaction
    Allowance: the quantity of tokens a wallet or Process can spend on behalf of the Sender

  It uses a constructor to set the initial state, which can be done only once.

  It attaches handlers according to the ao20 Token Spec API:

    - Info(): return the token parameters, like Name, Ticker, Logo, and Denomination

    - TotalSupply(): return the current total supply of tokens

    - Balance(Target?: string): return the token balance of the Target. If Target is not provided, the Sender
        is assumed to be the Target

    - Balances(): return the token balance of all participants

    - Transfer(Recipient: string, Quantity: number): if the Sender has a sufficient balance, and the Recipient has sufficient allowance, 
        send the specified Quantity to the Recipient. It will also issue a Credit-Notice to the Recipient and a Debit-Notice to the Sender.

    - Allowance(Spender: string): return Spender token allowance approved by the Sender.

    - Allowances(): return the approved token allowances of all participants

    - Approve(Spender: string, Quantity: number): set the Sender token allowance approved by the Sender. It will also issue
        an Approval-Notice to the Spender and an Approve-Notice to the Sender.

    - TransferFrom(Sender: string, Recipient: string, Quantity: number): if the Sender has a sufficient balance, and the Spender 
        has sufficient allowance, send the specified Quantity to the Recipient. It will also issue a Credit-Notice to the Recipient, a 
        Debit-Notice to the Sender and a Transfer-Notice to the Spender if they are not also the Sender.

    - Mint(Quantity: number, Recipient?): if the contract is Mintable and the Sender matches the Process Owner, then mint the desired Quantity 
        of tokens. If a Recipient is not provided, tokens are minted to the Processes' balance. It will also issue a Credit-Notice to the Recipient.

    - Burn(Quantity: number): if the contract is Burnable and the Sender has a sufficient balance, then burn the desired Quantity of tokens.
        It will also issue a Debit-Notice to the Sender.

    - BurnFrom(Sender: string, Quantity: number): if the Sender has sufficient balance and the Spender has a sufficient allowance, 
        then burn the desired Quantity of tokens. It will also issue a Debit-Notice to the Sender and a Transfer-Notice to the Spender.

    - Pause(Paused: boolean): if the contract is Pausable and the Sender matches the Process Owner, then set the contract pause state.
        It will also issue a Pause-Notice to the Sender.

    - RenounceOwnership(): if the Sender matches the Process Owner, then renounce the contract ownership by setting the Owner to nil.
        It will also issue a Renounce-Ownership-Notice to the Sender.

    - TransferOwnership(Owner: string): if the Sender matches the Process Owner, then transfer the contract ownership to the new Owner.
        It will also issue a New-Ownership-Notice to the new Owner and an Ownership-Transfer-Notice to the Sender.
]]
--

local bint = require('.bint')(256)
local ao = require('ao')
local token = require('.ao20')

local ao20 = {
  _version = "0.0.21",
  token = token,
  process = "IVoKzaQNotDFXKlilVprJU8FKli_N-Az99zMZWHzids"
}

--[[
     Constructor used to initialize the contract - can only be called once
   ]]
--

--[[
     Constructor
   ]]
--
-- @dev Update this constructor call to set the initial state of your token.
ao20.token.constructor(
  {
    -- set initial balances
    balances = {
      -- process: 100 tokens
      [ao.id] = tostring(bint(1000000000000)),
      -- alice:   300 tokens
      ["XkVOo16KMIHK-zqlR67cuNY0ayXIkPWODWw_HXAE20I"] = tostring(bint(3000000000000)),
      -- bob:     100 tokens
      ["m6W6wreOSejTb2WRHoALM6M7mw3H8D2KmFVBYC1l0O0"] = tostring(bint(1000000000000))
    },
    name = "My Coin",
    ticker = "COIN",
    denomination = "10",
    logo = "TXID of logo image",
    burnable = true,
    mintable = true,
    pausable = true,
    paused = false,
    owner = "XkVOo16KMIHK-zqlR67cuNY0ayXIkPWODWw_HXAE20I"
  }
)

--[[
     Handlers for each incoming Action as defined by the ao20 Token Specification
   ]]
--

--[[
     Init
   ]]
--
Handlers.add('init', Handlers.utils.hasMatchingTag('Action', 'Init'), function(msg)
  ao20.token.init(msg)
end)

--[[
     Info
   ]]
--
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
  ao20.token.info(msg)
end)

--[[
     Total Supply
   ]]
--
Handlers.add('totalSupply', Handlers.utils.hasMatchingTag('Action', 'TotalSupply'), function(msg)
  ao20.token.totalSupply(msg)
end)

--[[
     Balance
   ]]
--
Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
  ao20.token.balance(msg)
end)

--[[
     Balances
   ]]
--
Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'), function(msg)
  ao20.token.balances(msg)
end)

--[[
     Transfer
   ]]
--
Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg)
  ao20.token.transfer(msg)
end)

--[[
     Allowance
   ]]
--
Handlers.add('allowance', Handlers.utils.hasMatchingTag('Action', 'Allowance'), function(msg)
  ao20.token.allowance(msg)
end)

--[[
     Allowances
   ]]
--
Handlers.add('allowances', Handlers.utils.hasMatchingTag('Action', 'Allowances'), function(msg)
  ao20.token.allowances(msg)
end)

--[[
     Approve
   ]]
--
Handlers.add('approve', Handlers.utils.hasMatchingTag('Action', 'Approve'), function(msg)
  ao20.token.approve(msg)
end)

--[[
     Transfer From
   ]]
--
Handlers.add('transferFrom', Handlers.utils.hasMatchingTag('Action', 'TransferFrom'), function(msg)
  ao20.token.transferFrom(msg)
end)

--[[
    Mint
   ]]
--
Handlers.add('mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), function (msg)
  ao20.token.mint(msg)
end)

--[[
    Burn
   ]]
--
Handlers.add('burn', Handlers.utils.hasMatchingTag('Action', 'Burn'), function (msg)
  ao20.token.burn(msg)
end)

--[[
    Burn From
   ]]
--
Handlers.add('burnFrom', Handlers.utils.hasMatchingTag('Action', 'BurnFrom'), function (msg)
  ao20.token.burnFrom(msg)
end)

--[[
    Pause
   ]]
--
Handlers.add('pause', Handlers.utils.hasMatchingTag('Action', 'Pause'), function (msg)
  ao20.token.pause(msg)
end)

--[[
    Renounce Ownership
   ]]
--
Handlers.add('renounceOwnership', Handlers.utils.hasMatchingTag('Action', 'RenounceOwnership'), function (msg)
  ao20.token.renounceOwnership(msg)
end)

--[[
    Transfer Ownership
   ]]
--
Handlers.add('transferOwnership', Handlers.utils.hasMatchingTag('Action', 'TransferOwnership'), function (msg)
  ao20.token.transferOwnership(msg)
end)

return ao20