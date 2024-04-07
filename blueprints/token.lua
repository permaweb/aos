local bint = require('.bint')(256)
local ao = require('ao')
local token = require('./mods/token')

if not Balances then Balances = { [ao.id] = tostring(bint(10000 * 1e12)) } end
if not Allowances then Allowances = {} end

if not Minter then Minter = '' end

if Name ~= '' then Name = '' end

if Ticker ~= '' then Ticker = '' end

if Denomination ~= 8 then Denomination = 8 end

if not Logo then Logo = '' end

--
Handlers.add('init', Handlers.utils.hasMatchingTag('Action', 'Init'), token.init)
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), token.info)
Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), token.balance)
Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'), token.balances)
Handlers.add('allowance', Handlers.utils.hasMatchingTag('Action', 'Allowance'), token.allowance)
Handlers.add('allowances', Handlers.utils.hasMatchingTag('Action', 'Allowances'), token.allowances)
Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), token.transfer)
Handlers.add('transferFrom', Handlers.utils.hasMatchingTag('Action', 'TransferFrom'), token.transferFrom)
Handlers.add('approve', Handlers.utils.hasMatchingTag('Action', 'Approve'), token.approve)
Handlers.add('mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), token.mint)
