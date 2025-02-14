--[[
	NOTE: constants is used throughout the codebase, so avoid imports of any modules in this file to prevent circular dependencies
]]
--
local constants = {}

--- Process constants
constants.LOGO = "qUjrTmHdVjXX4D6rU6Fik02bUOzWkOR6oOqUg39g4-s"
constants.TICKER = "ARIO"
constants.NAME = "ARIO"
constants.DENOMINATION = 6

-- intentionally not exposed so all callers use ARIOToMARIO for consistency
local mARIO_PER_ARIO = 10 ^ constants.DENOMINATION -- 1 million mARIO per ARIO

--- @param ARIO number
--- @return mARIO mARIO the amount of mario for the given ARIO
function constants.ARIOToMARIO(ARIO)
	return math.floor(ARIO * mARIO_PER_ARIO)
end

--- @param days number
--- @return number milliseconds the number of days in milliseconds
function constants.daysToMs(days)
	return days * constants.hoursToMs(24)
end

--- @param minutes number
--- @return number milliseconds the number of minutes in milliseconds
function constants.minutesToMs(minutes)
	return minutes * constants.secondsToMs(60)
end

function constants.secondsToMs(seconds)
	return seconds * 1000
end

--- @param years number
--- @return number milliseconds the number of years in milliseconds
function constants.yearsToMs(years)
	return years * constants.daysToMs(365)
end

function constants.hoursToMs(hours)
	return hours * constants.minutesToMs(60)
end

-- TOKEN SUPPLY
constants.TOTAL_TOKEN_SUPPLY = constants.ARIOToMARIO(10 ^ 9) -- 1 billion tokens
constants.DEFAULT_PROTOCOL_BALANCE = constants.ARIOToMARIO(65 * (10 ^ 6)) -- 65M ARIO
constants.MIN_UNSAFE_ADDRESS_LENGTH = 1
constants.MAX_UNSAFE_ADDRESS_LENGTH = 128

-- EPOCHS
constants.DEFAULT_EPOCH_SETTINGS = {
	prescribedNameCount = 2, -- observers choose 8 names per epoch
	maxObservers = 50,
	epochZeroStartTimestamp = 1741176000000, -- March 5, 2025 12:00:00 UTC (7AM EST)
	durationMs = constants.daysToMs(1), -- 1 day
}

-- DISTRIBUTIONS
--[[
	Distribution rewards will be 0.1% of the protocol balance for the first year,
	then decay linearly to 0.05% of the protocol balance after the first year until 1.5 years.
	After 1.5 years, the reward rate will be 0.05% of the protocol balance.
]]
--
constants.DEFAULT_DISTRIBUTION_SETTINGS = {
	maximumRewardRate = 0.001, -- 0.1% of the protocol balance for the first year
	minimumRewardRate = 0.0005, -- 0.05% of the protocol balance after the first year
	rewardDecayStartEpoch = 365, -- one year of epochs before it kicks in
	rewardDecayLastEpoch = 547, -- 1.5 years of epochs before it stops (365 + 182)
	gatewayOperatorRewardRate = 0.9, -- (90%) the rate of rewards that go to the gateway operators
	observerRewardRate = 0.1, -- (10%) the rate of rewards that go to the observers
	missedObservationPenaltyRate = 0.25, -- (25%) penalty for gateways that receive rewards but did not observe
}

-- Gateway Address Registry
constants.MIN_WITHDRAWAL_AMOUNT = constants.ARIOToMARIO(1)
constants.DEFAULT_GAR_SETTINGS = {
	observers = {
		tenureWeightDurationMs = constants.daysToMs(180), -- 180 days in ms
		maxTenureWeight = 4, -- the maximum tenure weight, reached when a gateway has been running for 2 years or more
	},
	operators = {
		minStake = constants.ARIOToMARIO(10000), -- 10,000 ARIO
		withdrawLengthMs = constants.daysToMs(90), -- 90 days to lower operator stake
		leaveLengthMs = constants.daysToMs(90), -- 90 days that balance will be vaulted
		failedEpochCountMax = 30, -- number of epochs failed before marked as leaving
		failedGatewaySlashRate = 1, -- (100%) applied to the minimum operator stake, the rest is vaulted
		maxDelegateRewardShareRatio = 95, -- (95%) the maximum percentage of rewards that can be shared with delegates, intentionally represented as a percentage (vs. rate)
	},
	delegates = {
		minStake = constants.ARIOToMARIO(10), -- 10 ARIO
		withdrawLengthMs = constants.daysToMs(90), -- 90 days once withdraw is requested, subject to redelegation rules and penalties for early withdrawal
	},
	redelegations = {
		minRedelegationPenaltyRate = 0.10, -- (10%) the minimum penalty rate for a redelegation
		maxRedelegationPenaltyRate = 0.60, -- (60%) the maximum penalty rate for a redelegation
		minRedelegationAmount = constants.MIN_WITHDRAWAL_AMOUNT, -- the minimum amount that can be redelegated
		redelegationFeeResetIntervalMs = constants.daysToMs(7), -- 7 days
	},
	expeditedWithdrawals = {
		minExpeditedWithdrawalPenaltyRate = 0.10, -- (10%) the minimum penalty rate for an expedited withdrawal
		maxExpeditedWithdrawalPenaltyRate = 0.50, -- (50%) the maximum penalty rate for an expedited withdrawal
		minExpeditedWithdrawalAmount = constants.MIN_WITHDRAWAL_AMOUNT, -- the minimum amount that can be expedited
	},
}

-- VAULTS
constants.MIN_VAULT_SIZE = constants.ARIOToMARIO(100) -- 100 ARIO - primarily to avoid state bloat and encouraged consolidated vaults
constants.MAX_TOKEN_LOCK_TIME_MS = constants.yearsToMs(200) -- The maximum amount of years tokens can be locked in a vault (200 years)
constants.MIN_TOKEN_LOCK_TIME_MS = constants.daysToMs(14) -- The minimum amount of years tokens can be locked in a vault (14 days)

-- ARNS
constants.DEFAULT_UNDERNAME_COUNT = 10
constants.MAX_NAME_LENGTH = 51 -- protects against invalid URLs when resolving arns names on gateways
constants.MIN_NAME_LENGTH = 1
-- Regex pattern to validate ARNS names:
-- - Starts with an alphanumeric character (%w)
-- - Can contain alphanumeric characters and hyphens (%w-)
-- - Ends with an alphanumeric character (%w)
-- - Does not allow names to start or end with a hyphen
constants.ARNS_NAME_REGEX = "^%w[%w-]*%w?$" -- TODO: validate tests around this
constants.PERMABUY_LEASE_FEE_LENGTH_YEARS = 20 -- buying a permabuy record is equal to leasing the name for 20 years
constants.ANNUAL_PERCENTAGE_FEE = 0.2 -- the fee applied for leases against the base name
constants.UNDERNAME_LEASE_FEE_PERCENTAGE = 0.001 -- for leased names the undername fee is 0.1% for one undername
constants.UNDERNAME_PERMABUY_FEE_PERCENTAGE = 0.005 -- for permabuy names the undername fee is 0.5% for one undername
constants.GRACE_PERIOD_DURATION_MS = constants.daysToMs(14) -- the grace period for expired names
constants.MAX_LEASE_LENGTH_YEARS = 5 -- the maximum number of years a name can be leased for
-- the returned period for names that have expired beyond their grace period or manually returned, where a multiplier is applied for purchasing
constants.RETURNED_NAME_DURATION_MS = constants.daysToMs(14)
constants.RETURNED_NAME_MAX_MULTIPLIER = 50 -- Freshly returned names will have a multiplier of 50x
constants.PRIMARY_NAME_REQUEST_DEFAULT_NAME_LENGTH = 51 -- primary name requests cost the same as a single undername on a 51 character name
constants.PRIMARY_NAME_REQUEST_DURATION_MS = constants.daysToMs(7) -- the duration of a primary name request
constants.GATEWAY_OPERATOR_ARNS_DISCOUNT_PERCENTAGE = 0.2 -- operator discount applied to arns requests
-- the tenure weight threshold for eligibility for the arns discount (you need to be an operator for 6 months to qualify)
constants.GATEWAY_OPERATOR_ARNS_DISCOUNT_TENURE_WEIGHT_ELIGIBILITY_THRESHOLD = 1
-- the gateway performance ratio threshold for eligibility for the arns discount (you need to have a 85% performance ratio to qualify)
constants.GATEWAY_OPERATOR_ARNS_DISCOUNT_PERFORMANCE_RATIO_ELIGIBILITY_THRESHOLD = 0.90 -- gateway must achieve a 90% performance ratio to qualify
constants.GATEWAY_OPERATOR_ARNS_DISCOUNT_NAME = "Gateway Operator ArNS Discount" -- the name of the discount applied to arns requests
-- TODO: these will likely be adjusted for mainnet
constants.DEFAULT_GENESIS_FEES = {
	[1] = constants.ARIOToMARIO(2000000),
	[2] = constants.ARIOToMARIO(200000),
	[3] = constants.ARIOToMARIO(40000),
	[4] = constants.ARIOToMARIO(10000),
	[5] = constants.ARIOToMARIO(4000),
	[6] = constants.ARIOToMARIO(2000),
	[7] = constants.ARIOToMARIO(1000),
	[8] = constants.ARIOToMARIO(600),
	[9] = constants.ARIOToMARIO(500),
	[10] = constants.ARIOToMARIO(500),
	[11] = constants.ARIOToMARIO(500),
	[12] = constants.ARIOToMARIO(500),
	[13] = constants.ARIOToMARIO(400),
	[14] = constants.ARIOToMARIO(400),
	[15] = constants.ARIOToMARIO(400),
	[16] = constants.ARIOToMARIO(400),
	[17] = constants.ARIOToMARIO(400),
	[18] = constants.ARIOToMARIO(400),
	[19] = constants.ARIOToMARIO(400),
	[20] = constants.ARIOToMARIO(400),
	[21] = constants.ARIOToMARIO(400),
	[22] = constants.ARIOToMARIO(400),
	[23] = constants.ARIOToMARIO(400),
	[24] = constants.ARIOToMARIO(400),
	[25] = constants.ARIOToMARIO(400),
	[26] = constants.ARIOToMARIO(400),
	[27] = constants.ARIOToMARIO(400),
	[28] = constants.ARIOToMARIO(400),
	[29] = constants.ARIOToMARIO(400),
	[30] = constants.ARIOToMARIO(400),
	[31] = constants.ARIOToMARIO(400),
	[32] = constants.ARIOToMARIO(400),
	[33] = constants.ARIOToMARIO(400),
	[34] = constants.ARIOToMARIO(400),
	[35] = constants.ARIOToMARIO(400),
	[36] = constants.ARIOToMARIO(400),
	[37] = constants.ARIOToMARIO(400),
	[38] = constants.ARIOToMARIO(400),
	[39] = constants.ARIOToMARIO(400),
	[40] = constants.ARIOToMARIO(400),
	[41] = constants.ARIOToMARIO(400),
	[42] = constants.ARIOToMARIO(400),
	[43] = constants.ARIOToMARIO(400),
	[44] = constants.ARIOToMARIO(400),
	[45] = constants.ARIOToMARIO(400),
	[46] = constants.ARIOToMARIO(400),
	[47] = constants.ARIOToMARIO(400),
	[48] = constants.ARIOToMARIO(400),
	[49] = constants.ARIOToMARIO(400),
	[50] = constants.ARIOToMARIO(400),
	[51] = constants.ARIOToMARIO(400),
}

--[[
	DEMAND FACTOR:
	The demand factor is used to adjust the fees for ARNS purchases. It is a moving average of the trailing period purchases and revenues.
	The formula to compute how many periods it would take to reset fees is math.ceil(log(demandFactorMin) / log(1 - demandFactorDownAdjustmentRate)) + maxPeriodsAtMinDemandFactor.
	With these values, it would take 46 periods to get to the minimum demand factor of 0.5. Then an additional 7 periods to reset fees to half of the initial fees.
]]
constants.DEFAULT_DEMAND_FACTOR = {
	currentPeriod = 1, -- one based index of the current period
	trailingPeriodPurchases = { 0, 0, 0, 0, 0, 0, 0 }, -- Acts as a ring buffer of trailing period purchase counts
	trailingPeriodRevenues = { 0, 0, 0, 0, 0, 0, 0 }, -- Acts as a ring buffer of trailing period revenues
	purchasesThisPeriod = 0,
	revenueThisPeriod = 0,
	currentDemandFactor = 1, -- TODO: start at a 2x demand factor to prevent sniping
	consecutivePeriodsWithMinDemandFactor = 0,
	fees = constants.DEFAULT_GENESIS_FEES,
}
constants.DEFAULT_DEMAND_FACTOR_SETTINGS = {
	periodZeroStartTimestamp = 1740009600000, -- 2025-02-20T00:00:00Z
	movingAvgPeriodCount = 7, -- the number of periods to use for the moving average
	periodLengthMs = constants.daysToMs(1), -- one day in milliseconds
	demandFactorBaseValue = 1, -- the base demand factor value that is what the demand factor is reset to when fees are reset
	demandFactorMin = 0.5, -- the minimum demand factor allowed, after which maxPeriodsAtMinDemandFactor is applied and fees are reset
	demandFactorUpAdjustmentRate = 0.05, -- (5%) the rate at which the demand factor increases each period, if demand is increasing (1 + this number)
	demandFactorDownAdjustmentRate = 0.015, -- (1.5%) the rate at which the demand factor decreases each period, if demand is decreasing (1 - this number)
	maxPeriodsAtMinDemandFactor = 7, -- 7 consecutive periods with the minimum demand factor before fees are reset
	criteria = "revenue", -- "revenue" or "purchases" -- TODO: confirm this is accrued over ALL arns purchases related events
}

return constants
