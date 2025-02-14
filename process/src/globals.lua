local constants = require(".src.constants")
local utils = require(".src.utils")
local ao = ao or require("ao")
local globals = {}

--[[
    Constants
]]
Name = Name or constants.NAME
Ticker = Ticker or constants.TICKER
Logo = Logo or constants.LOGO
Denomination = Denomination or constants.DENOMINATION

--[[
    Balances
]]
Balances = Balances or {}
Balances[ao.id] = constants.DEFAULT_PROTOCOL_BALANCE

--[[
    Token Supply
]]
--- @type number
TotalSupply = TotalSupply or constants.TOTAL_TOKEN_SUPPLY

--[[
    Gateway Registry
]]
--- @alias Gateways table<WalletAddress, Gateway>
--- @type Gateways
GatewayRegistry = GatewayRegistry or {}
--- @type GatewayRegistrySettings
GatewayRegistrySettings = GatewayRegistrySettings or utils.deepCopy(constants.DEFAULT_GAR_SETTINGS)

--[[
    Epochs
]]
--- @alias Epochs table<number, PrescribedEpoch>
--- @type Epochs
Epochs = Epochs or {}
--- @type EpochSettings
EpochSettings = EpochSettings or utils.deepCopy(constants.DEFAULT_EPOCH_SETTINGS)
--- @type DistributionSettings
DistributionSettings = DistributionSettings or utils.deepCopy(constants.DEFAULT_DISTRIBUTION_SETTINGS)

--[[
    NameRegistry
]]
--- @type NameRegistry
NameRegistry = NameRegistry or {
	reserved = {},
	records = {},
	returned = {},
}

--[[
    Primary Names
]]
--- @type PrimaryNames
PrimaryNames = PrimaryNames or {
	requests = {},
	names = {},
	owners = {},
}

--[[
    DemandFactor
]]
--- @type DemandFactor
DemandFactor = DemandFactor or utils.deepCopy(constants.DEFAULT_DEMAND_FACTOR)
--- @type DemandFactorSettings
DemandFactorSettings = DemandFactorSettings or utils.deepCopy(constants.DEFAULT_DEMAND_FACTOR_SETTINGS)

--[[
    Vaults
]]
--- @type Vaults
Vaults = Vaults or {}

--[[
    Last Known Variables - primarily used for eventing and pruning
]]
--- @type Timestamp|nil
LastKnownMessageTimestamp = LastKnownMessageTimestamp or 0
--- @type string
LastKnownMessageId = LastKnownMessageId or ""
--- @type Timestamp|nil
LastGracePeriodEntryEndTimestamp = LastGracePeriodEntryEndTimestamp or 0
--- @type number
LastCreatedEpochIndex = LastCreatedEpochIndex or -1
--- @type number
LastDistributedEpochIndex = LastDistributedEpochIndex or 0
--- @type number
LastKnownCirculatingSupply = LastKnownCirculatingSupply or 0 -- total circulating supply (e.g. balances - protocol balance)
--- @type number
LastKnownLockedSupply = LastKnownLockedSupply or 0 -- total vault balance across all vaults
--- @type number
LastKnownStakedSupply = LastKnownStakedSupply or 0 -- total operator stake across all gateways
--- @type number
LastKnownDelegatedSupply = LastKnownDelegatedSupply or 0 -- total delegated stake across all gateways
--- @type number
LastKnownWithdrawSupply = LastKnownWithdrawSupply or 0 -- total withdraw supply across all gateways (gateways and delegates)

--[[
    Pruning Timestamps
]]
--- @type Timestamp|nil
NextRecordsPruneTimestamp = NextRecordsPruneTimestamp or 0
--- @type Timestamp|nil
NextReturnedNamesPruneTimestamp = NextReturnedNamesPruneTimestamp or 0
--- @type Timestamp|nil
NextPrimaryNamesPruneTimestamp = NextPrimaryNamesPruneTimestamp or 0
--- @type Timestamp|nil
NextBalanceVaultsPruneTimestamp = NextBalanceVaultsPruneTimestamp or 0
--- @type Timestamp|nil
NextGatewayVaultsPruneTimestamp = NextGatewayVaultsPruneTimestamp or 0
--- @type Timestamp|nil
NextGatewaysPruneTimestamp = NextGatewaysPruneTimestamp or 0
--- @type Timestamp|nil
NextRedelegationsPruneTimestamp = NextRedelegationsPruneTimestamp or 0

return globals
