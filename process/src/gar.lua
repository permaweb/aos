local balances = require(".src.balances")
local constants = require(".src.constants")
local utils = require(".src.utils")
local gar = {}

--- @class GatewayRegistrySettings
--- @field observers ObserverSettings
--- @field operators OperatorSettings
--- @field delegates DelegateSettings
--- @field expeditedWithdrawals ExpeditedWithdrawalsSettings

--- @class CompactGatewaySettings
--- @field allowDelegatedStaking boolean
--- @field allowedDelegatesLookup table<WalletAddress, boolean> | nil
--- @field delegateRewardShareRatio number
--- @field autoStake boolean
--- @field minDelegatedStake number
--- @field label string
--- @field fqdn string
--- @field protocol string
--- @field port number
--- @field properties string
--- @field note string | nil

--- @class CompactGateway
--- @field operatorStake number
--- @field totalDelegatedStake number
--- @field startTimestamp Timestamp
--- @field endTimestamp Timestamp|nil
--- @field stats GatewayStats
--- @field settings CompactGatewaySettings
--- @field services GatewayServices | nil
--- @field status "joined"|"leaving"
--- @field observerAddress WalletAddress
--- @field weights GatewayWeights
--- @field slashings table<Timestamp, mARIO> | nil

--- @class Gateway : CompactGateway
--- @field vaults table<WalletAddress, Vault>
--- @field delegates table<WalletAddress, Delegate>
--- @field settings GatewaySettings

--- @class GatewayStats
--- @field prescribedEpochCount number
--- @field observedEpochCount number
--- @field totalEpochCount number
--- @field passedEpochCount number
--- @field failedEpochCount number
--- @field failedConsecutiveEpochs number
--- @field passedConsecutiveEpochs number

--- @class GatewaySettings : CompactGatewaySettings
--- @field allowedDelegatesLookup table<WalletAddress, boolean> | nil

--- @class GatewayWeights
--- @field stakeWeight number
--- @field tenureWeight number
--- @field gatewayPerformanceRatio number
--- @field observerPerformanceRatio number
--- @field compositeWeight number
--- @field normalizedCompositeWeight number

--- @alias GatewayServices table<'bundler', GatewayService>

--- @class GatewayService
--- @field fqdn string
--- @field port number
--- @field path string
--- @field protocol string

--- @alias MessageId string
--- @alias Timestamp number

--- @class Delegate
--- @field delegatedStake number
--- @field startTimestamp Timestamp
--- @field vaults table<MessageId, Vault>

--- @class ObserverSettings
--- @field tenureWeightDays number
--- @field tenureWeightDurationMs number
--- @field maxTenureWeight number

--- @class OperatorSettings
--- @field minStake number
--- @field withdrawLengthMs number
--- @field leaveLengthMs number
--- @field failedEpochCountMax number
--- @field failedGatewaySlashRate number
--- @field maxDelegateRewardShareRatio number
--- @class ExpeditedWithdrawalsSettings
--- @field minExpeditedWithdrawalPenaltyRate number
--- @field maxExpeditedWithdrawalPenaltyRate number
--- @field minExpeditedWithdrawalAmount number

--- @class DelegateSettings
--- @field minStake number
--- @field withdrawLengthMs number

--- @class JoinGatewaySettings
--- @field allowDelegatedStaking boolean | nil
--- @field allowedDelegates WalletAddress[] | nil
--- @field delegateRewardShareRatio number | nil
--- @field autoStake boolean | nil
--- @field minDelegatedStake number
--- @field label string
--- @field fqdn string
--- @field protocol string
--- @field port number
--- @field properties string
--- @field note string | nil

--- Joins the network with the given parameters
--- @param from WalletAddress The address from which the request is made
--- @param stake mARIO: The amount of stake to be used
--- @param settings JoinGatewaySettings The settings for joining the network
--- @param services GatewayServices|nil The services to be used in the network
--- @param observerAddress WalletAddress The address of the observer
--- @param timeStamp Timestamp The timestamp of the request
--- @return Gateway # Returns the newly joined gateway
function gar.joinNetwork(from, stake, settings, services, observerAddress, timeStamp)
	gar.assertValidGatewayParameters(from, stake, settings, services, observerAddress)

	assert(not gar.getGateway(from), "Gateway already exists")
	assert(balances.walletHasSufficientBalance(from, stake), "Insufficient balance")

	local newGateway = {
		operatorStake = stake,
		totalDelegatedStake = 0,
		vaults = {},
		delegates = {},
		startTimestamp = timeStamp,
		stats = {
			prescribedEpochCount = 0,
			observedEpochCount = 0,
			totalEpochCount = 0,
			passedEpochCount = 0,
			failedEpochCount = 0,
			failedConsecutiveEpochs = 0,
			passedConsecutiveEpochs = 0,
		},
		settings = {
			allowDelegatedStaking = settings.allowDelegatedStaking or false,
			allowedDelegatesLookup = settings.allowedDelegates and utils.createLookupTable(settings.allowedDelegates)
				or nil,
			delegateRewardShareRatio = settings.delegateRewardShareRatio or 0,
			autoStake = settings.autoStake or true,
			minDelegatedStake = settings.minDelegatedStake or gar.getSettings().delegates.minStake,
			label = settings.label,
			fqdn = settings.fqdn,
			protocol = settings.protocol or "https",
			port = settings.port or 443,
			properties = settings.properties,
			note = settings.note or "",
		},
		services = services or nil,
		status = "joined",
		observerAddress = observerAddress or from,
		weights = {
			stakeWeight = 0,
			tenureWeight = 0,
			gatewayPerformanceRatio = 0,
			observerPerformanceRatio = 0,
			compositeWeight = 0,
			normalizedCompositeWeight = 0,
		},
	}

	local gateway = gar.addGateway(from, newGateway)
	balances.reduceBalance(from, stake)
	return gateway
end

--- @param from WalletAddress the address of the gateway to exit
--- @param currentTimestamp Timestamp
--- @param msgId MessageId
--- @return Gateway # a copy of the updated gateway
function gar.leaveNetwork(from, currentTimestamp, msgId)
	local gateway = gar.getGateway(from)

	assert(gateway, "Gateway not found")
	assert(gar.isGatewayEligibleToLeave(gateway, currentTimestamp), "The gateway is not eligible to leave the network.")

	local gatewayEndTimestamp = currentTimestamp + gar.getSettings().operators.leaveLengthMs
	local minimumStakedTokens = math.min(gar.getSettings().operators.minStake, gateway.operatorStake)
	local gatewayStakeWithdrawTimestamp = currentTimestamp + gar.getSettings().operators.withdrawLengthMs

	-- if the slash happens to be 100% we do not need to vault anything
	if minimumStakedTokens > 0 then
		createGatewayExitVault(gateway, minimumStakedTokens, currentTimestamp, from)

		-- if there is more than the minimum staked tokens, we need to vault the rest but on shorter term
		local remainingStake = gateway.operatorStake - gar.getSettings().operators.minStake

		if remainingStake > 0 then
			createGatewayWithdrawVault(gateway, msgId, remainingStake, currentTimestamp)
			gar.scheduleNextGatewaysPruning(gatewayStakeWithdrawTimestamp)
		end
	end

	gateway.status = "leaving"
	gateway.endTimestamp = gatewayEndTimestamp
	gateway.operatorStake = 0
	gar.scheduleNextGatewaysPruning(gatewayEndTimestamp)

	-- Add tokens from each delegate to a vault that unlocks after the delegate withdrawal period ends
	for address, _ in pairs(gateway.delegates) do
		gar.kickDelegateFromGateway(address, gateway, msgId, currentTimestamp)
	end

	-- update global state
	GatewayRegistry[from] = gateway
	return utils.deepCopy(gateway)
end

--- Increases the operator stake for a gateway
---@param from string # The address of the gateway to increase stake for
---@param qty number # The amount of stake to increase by - must be positive integer
---@return table # The updated gateway object
function gar.increaseOperatorStake(from, qty)
	assert(type(qty) == "number", "Quantity is required and must be a number")
	assert(qty > 0 and utils.isInteger(qty), "Quantity must be an integer greater than 0")

	local gateway = gar.getGateway(from)
	assert(gateway, "Gateway not found")
	assert(gateway.status ~= "leaving", "Gateway is leaving the network and cannot accept additional stake.")
	assert(balances.walletHasSufficientBalance(from, qty), "Insufficient balance")

	balances.reduceBalance(from, qty)
	gateway.operatorStake = gateway.operatorStake + qty
	-- update the gateway
	GatewayRegistry[from] = gateway
	return gateway
end

-- Utility function to calculate withdrawal details and handle balance adjustments
---@param stake number # The amount of stake to withdraw in mARIO
---@param elapsedTimeMs number # The amount of time that has elapsed since the withdrawal started
---@param totalWithdrawalTimeMs number # The total amount of time the withdrawal will take
---@param from string # The address of the operator or delegate
---@return number # The penalty rate as a percentage
---@return number # The expedited withdrawal fee in mARIO, given to the protocol balance
---@return number # The final amount withdrawn, after the penalty fee is subtracted and moved to the from balance
local function processInstantWithdrawal(stake, elapsedTimeMs, totalWithdrawalTimeMs, from)
	-- Calculate the withdrawal fee and the amount to withdraw
	local maxPenaltyRate = gar.getSettings().expeditedWithdrawals.maxExpeditedWithdrawalPenaltyRate
	local minPenaltyRate = gar.getSettings().expeditedWithdrawals.minExpeditedWithdrawalPenaltyRate
	local penaltyRateDecay = (maxPenaltyRate - minPenaltyRate) * elapsedTimeMs / totalWithdrawalTimeMs
	local penaltyRateAfterDecay = maxPenaltyRate - penaltyRateDecay
	-- the maximum rate they'll pay based on the decay
	local maximumPenaltyRate = math.min(maxPenaltyRate, penaltyRateAfterDecay)
	-- take the maximum rate between the minimum rate and the maximum rate after decay
	local floatingPenaltyRate = math.max(minPenaltyRate, maximumPenaltyRate)

	-- round to three decimal places to avoid floating point precision loss with small numbers
	local finalPenaltyRate = utils.roundToPrecision(floatingPenaltyRate, 3)
	-- round down to avoid any floating point precision loss with small numbers
	local expeditedWithdrawalFee = math.floor(stake * finalPenaltyRate)
	local amountToWithdraw = stake - expeditedWithdrawalFee

	-- Withdraw the tokens to the delegate and the protocol balance
	balances.increaseBalance(ao.id, expeditedWithdrawalFee)
	balances.increaseBalance(from, amountToWithdraw)

	return expeditedWithdrawalFee, amountToWithdraw, finalPenaltyRate
end

function gar.decreaseOperatorStake(from, qty, currentTimestamp, msgId, instantWithdraw)
	assert(type(qty) == "number", "Quantity is required and must be a number")
	assert(qty > 0, "Quantity must be greater than 0")

	local gateway = gar.getGateway(from)

	assert(gateway, "Gateway not found")
	assert(gateway.status ~= "leaving", "Gateway is leaving the network and cannot withdraw more stake.")

	local maxWithdraw = gateway.operatorStake - gar.getSettings().operators.minStake

	assert(
		qty <= maxWithdraw,
		"Resulting stake of "
			.. gateway.operatorStake - qty
			.. " mARIO is not enough to maintain the minimum operator stake of "
			.. gar.getSettings().operators.minStake
			.. " mARIO"
	)

	gateway.operatorStake = gateway.operatorStake - qty

	local expeditedWithdrawalFee = 0
	local amountToWithdraw = 0
	local penaltyRate = 0
	if instantWithdraw == true then
		-- Calculate the penalty and withdraw using the utility function
		expeditedWithdrawalFee, amountToWithdraw, penaltyRate = processInstantWithdrawal(qty, 0, 0, from)
	else
		createGatewayWithdrawVault(gateway, msgId, qty, currentTimestamp)
		gar.scheduleNextGatewaysPruning(gateway.vaults[msgId].endTimestamp)
	end

	-- Update the gateway
	GatewayRegistry[from] = gateway

	return {
		gateway = gateway,
		penaltyRate = penaltyRate,
		expeditedWithdrawalFee = expeditedWithdrawalFee,
		amountWithdrawn = amountToWithdraw,
	}
end

--- @class UpdateGatewaySettings : GatewaySettings
--- @field allowDelegatedStaking boolean | nil
--- @field allowedDelegates WalletAddress[] | nil
--- @field delegateRewardShareRatio number | nil
--- @field autoStake boolean | nil
--- @field minDelegatedStake number | nil
--- @field note string | nil

--- @param from WalletAddress
--- @param updatedSettings UpdateGatewaySettings
--- @param updatedServices GatewayServices|nil
--- @param observerAddress WalletAddress
--- @param currentTimestamp Timestamp
--- @param msgId MessageId
--- @return Gateway # the updated gateway
function gar.updateGatewaySettings(from, updatedSettings, updatedServices, observerAddress, currentTimestamp, msgId)
	local gateway = gar.getGateway(from)
	assert(gateway, "Gateway not found")
	assert(gateway.status ~= "leaving", "Gateway is leaving the network and cannot be updated")

	gar.assertValidGatewayParameters(from, gateway.operatorStake, updatedSettings, updatedServices, observerAddress)

	assert(
		not updatedSettings.minDelegatedStake
			or updatedSettings.minDelegatedStake >= gar.getSettings().delegates.minStake,
		"The minimum delegated stake must be at least " .. gar.getSettings().delegates.minStake .. " mARIO"
	)

	for gatewayAddress, existingGateway in pairs(gar.getGatewaysUnsafe()) do
		local invalidObserverAddress = existingGateway.observerAddress == observerAddress and gatewayAddress ~= from
		assert(
			not invalidObserverAddress,
			"Invalid observer wallet. The provided observer wallet is correlated with another gateway."
		)
	end

	-- update the allow list first if necessary since we may need it for accounting in any subsequent delegate kicks
	if updatedSettings.allowDelegatedStaking and updatedSettings.allowedDelegates then
		-- Replace the existing lookup table
		--- @diagnostic disable-next-line: inject-field
		updatedSettings.allowedDelegatesLookup = utils.createLookupTable(updatedSettings.allowedDelegates)
		updatedSettings.allowedDelegates = nil -- no longer need the list now that lookup is built

		-- remove any delegates that are not in the allowlist
		for delegateAddress, delegate in pairs(gateway.delegates) do
			if updatedSettings.allowedDelegatesLookup[delegateAddress] then
				if delegate.delegatedStake > 0 then
					-- remove the delegate from the lookup since it's adequately tracked as a delegate already
					updatedSettings.allowedDelegatesLookup[delegateAddress] = nil
				end
			elseif delegate.delegatedStake > 0 then
				gar.kickDelegateFromGateway(delegateAddress, gateway, msgId, currentTimestamp)
			end
			-- else: the delegate was exiting already with 0-balance and will no longer be on the allowlist
		end
	end

	if not updatedSettings.allowDelegatedStaking then
		-- Add tokens from each delegate to a vault that unlocks after the delegate withdrawal period ends
		if next(gateway.delegates) ~= nil then -- staking disabled and delegates must go
			for address, _ in pairs(gateway.delegates) do
				gar.kickDelegateFromGateway(address, gateway, msgId, currentTimestamp)
			end
		end

		-- clear the allowedDelegatesLookup since we no longer need it
		--- @diagnostic disable-next-line: inject-field
		updatedSettings.allowedDelegatesLookup = nil
	end

	-- if allowDelegateStaking is currently false, and you want to set it to true - you have to wait until all the vaults have been returned
	assert(
		not (
				updatedSettings.allowDelegatedStaking
				and not gateway.settings.allowDelegatedStaking
				and next(gateway.delegates)
			),
		"You cannot enable delegated staking until all delegated stakes have been withdrawn."
	)

	gateway.settings = updatedSettings
	if updatedServices then
		gateway.services = updatedServices
	end
	if observerAddress then
		gateway.observerAddress = observerAddress
	end
	-- update the gateway on the global state
	GatewayRegistry[from] = gateway
	return gateway
end

--- Gets a copy of a gateway by address
---@param address WalletAddress The address of the gateway to fetch
---@return Gateway|nil A gateway object copy or nil if not found
function gar.getGateway(address)
	return utils.deepCopy(GatewayRegistry[address])
end

--- Gets a copy of a gateway by address, minus its vaults, delegates, and allowlist
---@param address WalletAddress The address of the gateway to fetch
---@return CompactGateway|nil A gateway object copy or nil if not found
function gar.getCompactGateway(address)
	return utils.deepCopy(GatewayRegistry[address], { "delegates", "vaults", "settings.allowedDelegatesLookup" })
end

--- Gets a gateway reference by address, preferably for read-only activities
---@param address string The address of the gateway to fetch
---@return Gateway|nil The gateway object or nil if not found
function gar.getGatewayUnsafe(address)
	return GatewayRegistry[address]
end

--- Gets all gateways
---@return Gateways # address-mapped, deep copies of all the gateways objects
function gar.getGateways()
	local gateways = utils.deepCopy(GatewayRegistry)
	return gateways or {}
end

--- @return Gateways # All the address-mapped gateway objects
function gar.getGatewaysUnsafe()
	return GatewayRegistry or {}
end

--- @alias CompactGateways table<WalletAddress, CompactGateway>
--- @return CompactGateways # address-mapped, deep copies of all the gateways objects without delegates, vaults, or allowlist
function gar.getCompactGateways()
	return utils.reduce(gar.getGatewaysUnsafe(), function(acc, gatewayAddress, gateway)
		acc[gatewayAddress] = utils.deepCopy(gateway, { "delegates", "vaults", "settings.allowedDelegatesLookup" })
		return acc
	end, {})
end

--- @param startTimestamp number
function gar.createDelegate(startTimestamp)
	return {
		delegatedStake = 0,
		startTimestamp = startTimestamp,
		vaults = {},
	}
end

--- @param delegate Delegate
--- @param gateway Gateway
--- @param quantity mARIO
function increaseDelegateStakeAtGateway(delegate, gateway, quantity)
	assert(delegate, "Delegate is required")
	assert(gateway, "Gateway is required")
	-- zero is allowed as it is a no-op
	assert(
		quantity and utils.isInteger(quantity) and quantity >= 0,
		"Quantity is required and must be an integer greater than or equal to 0: " .. quantity
	)
	delegate.delegatedStake = delegate.delegatedStake + quantity
	gateway.totalDelegatedStake = gateway.totalDelegatedStake + quantity
end

--- @param delegateAddress WalletAddress
--- @param gateway Gateway
--- @param quantity mARIO
--- @param ban boolean|nil do not add the delegate back to the gateway allowlist if their delegation is over
--- @return Delegate, boolean # a copy of the updated delegate and whether or not it was pruned
function decreaseDelegateStakeAtGateway(delegateAddress, gateway, quantity, ban)
	local delegate = gateway.delegates[delegateAddress]
	assert(delegate, "Delegate is required")
	-- zero is allowed as it is a no-op
	assert(
		quantity and utils.isInteger(quantity) and quantity >= 0,
		"Quantity is required and must be an integer greater than or equal to 0: " .. quantity
	)
	assert(gateway, "Gateway is required")
	assert(quantity <= delegate.delegatedStake, "Quantity cannot be greater than the delegate's stake")
	assert(
		quantity <= gateway.totalDelegatedStake,
		"Quantity cannot be greater than the gateway's total delegated stake"
	)
	delegate.delegatedStake = delegate.delegatedStake - quantity
	gateway.totalDelegatedStake = gateway.totalDelegatedStake - quantity
	local pruned = gar.pruneDelegateFromGatewayIfNecessary(delegateAddress, gateway)
	if ban and gateway.settings.allowedDelegatesLookup then
		gateway.settings.allowedDelegatesLookup[delegateAddress] = nil
	end
	return utils.deepCopy(delegate), pruned
end

--- Creates a delegate at a gateway, managing allowlisting accounting if necessary
--- @param startTimestamp number
--- @param gateway Gateway
--- @param delegateAddress WalletAddress
--- @return Delegate # the created delegate
function gar.createDelegateAtGateway(startTimestamp, gateway, delegateAddress)
	-- prune user from allow list, if necessary, to save memory
	if gateway.settings.allowedDelegatesLookup then
		gateway.settings.allowedDelegatesLookup[delegateAddress] = nil
	end
	local newDelegate = gar.createDelegate(startTimestamp)
	gateway.delegates[delegateAddress] = newDelegate
	return newDelegate
end

--- @param balance mARIO # the starting balance of the vault
--- @param startTimestamp number # the timestamp when the vault was created
--- @return Vault # a vault with the specified balance, start timestamp, and computed end timestamp
function gar.createDelegateVault(balance, startTimestamp)
	local vault = {
		balance = balance,
		startTimestamp = startTimestamp,
		endTimestamp = startTimestamp + gar.getSettings().delegates.withdrawLengthMs,
	}
	gar.scheduleNextGatewaysPruning(vault.endTimestamp)
	return vault
end

function gar.delegateStake(from, target, qty, currentTimestamp)
	assert(type(qty) == "number", "Quantity is required and must be a number")
	assert(qty > 0, "Quantity must be greater than 0")
	assert(type(target) == "string", "Target is required and must be a string")
	assert(type(from) == "string", "From is required and must be a string")

	local gateway = gar.getGateway(target)
	assert(gateway, "Gateway not found")
	assert(gateway.status ~= "leaving", "Gateway is leaving the network and cannot have more stake delegated to it.")

	-- don't allow delegating to yourself
	assert(from ~= target, "Cannot delegate to your own gateway, use increaseOperatorStake instead.")
	assert(balances.walletHasSufficientBalance(from, qty), "Insufficient balance")
	assert(gateway.settings.allowDelegatedStaking, "This Gateway does not allow delegated staking.")
	assert(gar.delegateAllowedToStake(from, gateway), "This Gateway does not allow this delegate to stake.")

	-- Assuming `gateway` is a table and `fromAddress` is defined
	local existingDelegate = gateway.delegates[from]
	local minimumStakeForGatewayAndDelegate
	-- if it is not an auto stake provided by the protocol, then we need to validate the stake amount meets the gateway's minDelegatedStake
	if existingDelegate and existingDelegate.delegatedStake ~= 0 then
		-- It already has a stake that is not zero
		minimumStakeForGatewayAndDelegate = 1 -- Delegate must provide at least one additional mARIO
	else
		-- Consider if the operator increases the minimum amount after you've already staked
		minimumStakeForGatewayAndDelegate = gateway.settings.minDelegatedStake
	end
	assert(
		qty >= minimumStakeForGatewayAndDelegate,
		"Quantity must be greater than the minimum delegated stake amount."
	)

	-- If this delegate has staked before, update its amount, if not, create a new delegated staker
	existingDelegate = existingDelegate or gar.createDelegateAtGateway(currentTimestamp, gateway, from)
	increaseDelegateStakeAtGateway(existingDelegate, gateway, qty)

	-- Decrement the user's balance
	balances.reduceBalance(from, qty)

	-- update the gateway
	GatewayRegistry[target] = gateway
	return gateway
end

--- Internal function to increase the stake of an existing delegate. This should only be called from epochs.lua
---@param gatewayAddress string # The gateway address to increase stake for (required)
---@param gateway table # The gateway object to increase stake for (required)
---@param delegateAddress string # The address of the delegate to increase stake for (required)
---@param qty number # The amount of stake to increase by - must be positive integer (required)
function gar.increaseExistingDelegateStake(gatewayAddress, gateway, delegateAddress, qty)
	assert(gateway, "Gateway not found")
	assert(delegateAddress, "Delegate address is required")
	assert(
		qty and utils.isInteger(qty) and qty > 0,
		"Quantity is required and must be an integer greater than 0: " .. qty
	)

	local delegate = gateway.delegates[delegateAddress]
	assert(delegate, "Delegate not found")

	-- consider case where delegate has been kicked from the gateway and has vaulted stake
	assert(gar.delegateAllowedToStake(delegateAddress, gateway), "This Gateway does not allow this delegate to stake.")

	increaseDelegateStakeAtGateway(gateway.delegates[delegateAddress], gateway, qty)
	GatewayRegistry[gatewayAddress] = gateway
	return gateway
end

---@return GatewayRegistrySettings # a deep copy of the gateway registry settings
function gar.getSettings()
	return utils.deepCopy(GatewayRegistrySettings)
end

--- @class DecreaseDelegateStakeReturn
--- @field gatewayTotalDelegatedStake mARIO The updated amount of total delegated stake at the gateway
--- @field updatedDelegate Delegate The updated delegate object
--- @field delegatePruned boolean Whether or not the delegate was pruned from the gateway
--- @field penaltyRate number The penalty rate for the expedited withdrawal, if applicable
--- @field expeditedWithdrawalFee number The fee deducted from the stake for the expedited withdrawal, if applicable
--- @field amountWithdrawn number The amount of stake withdrawn after any penalty fee is deducted

--- @param gatewayAddress WalletAddress The address of the gateway from which to decrease delegated stake
--- @param delegator WalletAddress The address of the delegator for which to decrease delegated stake
--- @param qty mARIO The amount of delegated stake to decrease
--- @param currentTimestamp Timestamp The current timestamp
--- @param messageId MessageId The message ID of the current action
--- @param instantWithdraw boolean Whether to withdraw the stake instantly; otherwise allow it to be vaulted
--- @return DecreaseDelegateStakeReturn # Details about the outcome of the operation
function gar.decreaseDelegateStake(gatewayAddress, delegator, qty, currentTimestamp, messageId, instantWithdraw)
	assert(type(qty) == "number", "Quantity is required and must be a number")
	assert(qty > 0, "Quantity must be greater than 0")

	local gateway = gar.getGateway(gatewayAddress)

	assert(gateway, "Gateway not found")
	assert(gateway.status ~= "leaving", "Gateway is leaving the network and cannot withdraw more stake.")

	local delegate = gateway.delegates[delegator]
	assert(delegate, "This delegate is not staked at this gateway.")

	local existingStake = delegate.delegatedStake
	local requiredMinimumStake = gateway.settings.minDelegatedStake
	local maxAllowedToWithdraw = existingStake - requiredMinimumStake
	assert(
		maxAllowedToWithdraw >= qty or qty == existingStake,
		"Remaining delegated stake must be greater than the minimum delegated stake. Adjust the amount or withdraw all stake."
	)

	-- Instant withdrawal logic with penalty
	local expeditedWithdrawalFee = 0
	local amountToWithdraw = 0
	local penaltyRate = 0

	if instantWithdraw == true then
		-- Calculate the penalty and withdraw using the utility function and move the balances
		expeditedWithdrawalFee, amountToWithdraw, penaltyRate = processInstantWithdrawal(qty, 0, 0, delegator)
	else
		createDelegateWithdrawVault(gateway, delegator, messageId, qty, currentTimestamp)
	end
	local updatedDelegate, pruned = decreaseDelegateStakeAtGateway(delegator, gateway, qty)

	-- update the gateway
	GatewayRegistry[gatewayAddress] = gateway
	return {
		gatewayTotalDelegatedStake = gateway.totalDelegatedStake,
		updatedDelegate = updatedDelegate,
		delegatePruned = pruned,
		penaltyRate = penaltyRate,
		expeditedWithdrawalFee = expeditedWithdrawalFee,
		amountWithdrawn = amountToWithdraw,
	}
end

function gar.isGatewayLeaving(gateway)
	return gateway.status == "leaving"
end

function gar.isGatewayEligibleToLeave(gateway, timestamp)
	assert(gateway, "Gateway not found")
	local isJoined = gar.isGatewayJoined(gateway, timestamp)
	return isJoined
end

function gar.isGatewayActiveBeforeTimestamp(startTimestamp, gateway)
	local didStartBeforeEpoch = gateway.startTimestamp <= startTimestamp
	local isNotLeaving = not gar.isGatewayLeaving(gateway)
	return didStartBeforeEpoch and isNotLeaving
end

--- Returns the addresses of the gateways that are active before a given timestamp
--- @param startTimestamp number The timestamp to check if the gateways are active before
--- @return WalletAddress[] # The addresses of the active gateways
function gar.getActiveGatewayAddressesBeforeTimestamp(startTimestamp)
	local activeGatewayAddresses = {}
	-- use pairs as gateways is a map
	for address, gateway in pairs(gar.getGatewaysUnsafe()) do
		if gar.isGatewayActiveBeforeTimestamp(startTimestamp, gateway) then
			table.insert(activeGatewayAddresses, address)
		end
	end
	return activeGatewayAddresses
end

--- Gets the weights of collection of gateways at a given timestamp
--- @param gatewayAddresses string[] The gateway addresses to get the weights for
--- @param timestamp number The timestamp to get the weights at
--- @return WeightedGateway[] # The weighted gateways
function gar.getGatewayWeightsAtTimestamp(gatewayAddresses, timestamp)
	local weightedObservers = {}
	local totalCompositeWeight = 0

	-- Iterate over gateways to calculate weights
	for _, gatewayAddress in pairs(gatewayAddresses) do
		-- okay to use unsafe here as we are not modifying the gateway, just computing the weights
		local gateway = gar.getGatewayUnsafe(gatewayAddress)
		if gateway then
			local totalStake = gateway.operatorStake + gateway.totalDelegatedStake -- 100 - no cap to this
			local stakeWeightRatio = totalStake / gar.getSettings().operators.minStake -- this is always greater than 1 as the minOperatorStake is always less than the stake
			-- the percentage of the epoch the gateway was joined for before this epoch, if the gateway starts in the future this will be 0
			local gatewayStartTimestamp = gateway.startTimestamp
			local totalTimeForGateway = timestamp >= gatewayStartTimestamp and (timestamp - gatewayStartTimestamp) or -1
			local calculatedTenureWeightForGateway = totalTimeForGateway < 0 and 0
				or (
					totalTimeForGateway > 0
						and totalTimeForGateway / gar.getSettings().observers.tenureWeightDurationMs
					or 1 / gar.getSettings().observers.tenureWeightDurationMs
				)
			local gatewayTenureWeight =
				math.min(calculatedTenureWeightForGateway, gar.getSettings().observers.maxTenureWeight)

			local totalEpochsGatewayPassed = gateway.stats.passedEpochCount or 0
			local totalEpochsParticipatedIn = gateway.stats.totalEpochCount or 0
			local gatewayPerformanceRatio = (1 + totalEpochsGatewayPassed) / (1 + totalEpochsParticipatedIn)
			local totalEpochsPrescribed = gateway.stats.prescribedEpochCount or 0
			local totalEpochsSubmitted = gateway.stats.observedEpochCount or 0
			local observerPerformanceRatio = (1 + totalEpochsSubmitted) / (1 + totalEpochsPrescribed)

			local compositeWeight = stakeWeightRatio
				* gatewayTenureWeight
				* gatewayPerformanceRatio
				* observerPerformanceRatio

			table.insert(weightedObservers, {
				gatewayAddress = gatewayAddress,
				observerAddress = gateway.observerAddress,
				stake = totalStake,
				startTimestamp = gateway.startTimestamp,
				stakeWeight = stakeWeightRatio,
				tenureWeight = gatewayTenureWeight,
				gatewayPerformanceRatio = gatewayPerformanceRatio,
				observerPerformanceRatio = observerPerformanceRatio,
				compositeWeight = compositeWeight,
				normalizedCompositeWeight = nil, -- set later once we have the total composite weight
			})

			totalCompositeWeight = totalCompositeWeight + compositeWeight
		end
	end

	-- Calculate the normalized composite weight for each observer
	for _, weightedObserver in pairs(weightedObservers) do
		if totalCompositeWeight > 0 then
			weightedObserver.normalizedCompositeWeight = weightedObserver.compositeWeight / totalCompositeWeight
		else
			weightedObserver.normalizedCompositeWeight = 0
		end
	end
	return weightedObservers
end

function gar.isGatewayJoined(gateway, currentTimestamp)
	return gateway.status == "joined" and gateway.startTimestamp <= currentTimestamp
end

function gar.assertValidGatewayParameters(from, stake, settings, services, observerAddress)
	assert(type(from) == "string", "from is required and must be a string")
	assert(type(stake) == "number", "stake is required and must be a number")
	assert(type(settings) == "table", "settings is required and must be a table")
	assert(
		type(observerAddress) == "string" and utils.isValidAddress(observerAddress, true),
		"Observer-Address is required and must be a a valid arweave address"
	)
	if settings.allowDelegatedStaking ~= nil then
		assert(type(settings.allowDelegatedStaking) == "boolean", "allowDelegatedStaking must be a boolean")
	end
	if type(settings.allowedDelegates) == "table" then
		for _, delegate in pairs(settings.allowedDelegates) do
			assert(utils.isValidAddress(delegate, true), "delegates in allowedDelegates must be valid AO addresses")
		end
	else
		assert(
			settings.allowedDelegates == nil,
			"allowedDelegates must be a table parsed from a comma-separated string or nil"
		)
	end

	assert(type(settings.label) == "string", "label is required and must be a string")
	assert(type(settings.fqdn) == "string", "fqdn is required and must be a string")
	if settings.protocol ~= nil then
		assert(
			type(settings.protocol) == "string" and settings.protocol == "https",
			"protocol is required and must be https"
		)
	end
	if settings.port ~= nil then
		assert(
			type(settings.port) == "number"
				and utils.isInteger(settings.port)
				and settings.port >= 0
				and settings.port <= 65535,
			"port is required and must be an integer between 0 and 65535"
		)
	end
	assert(
		type(settings.properties) == "string" and utils.isValidAddress(settings.properties, true),
		"properties is required and must be a string"
	)
	assert(
		stake >= gar.getSettings().operators.minStake,
		"Operator stake must be greater than the minimum stake to join the network"
	)
	if settings.delegateRewardShareRatio ~= nil then
		assert(
			type(settings.delegateRewardShareRatio) == "number"
				and utils.isInteger(settings.delegateRewardShareRatio)
				and settings.delegateRewardShareRatio >= 0
				and settings.delegateRewardShareRatio <= gar.getSettings().operators.maxDelegateRewardShareRatio,
			"delegateRewardShareRatio must be an integer between 0 and "
				.. gar.getSettings().operators.maxDelegateRewardShareRatio
		)
	end
	if settings.autoStake ~= nil then
		assert(type(settings.autoStake) == "boolean", "autoStake must be a boolean")
	end
	if settings.properties ~= nil then
		assert(type(settings.properties) == "string", "properties must be a table")
	end
	if settings.minDelegatedStake ~= nil then
		assert(
			type(settings.minDelegatedStake) == "number"
				and utils.isInteger(settings.minDelegatedStake)
				and settings.minDelegatedStake >= gar.getSettings().delegates.minStake,
			"minDelegatedStake must be an integer greater than or equal to the minimum delegated stake"
		)
	end

	if services ~= nil then
		assert(type(services) == "table", "services must be a table")

		local allowedServiceKeys = { bundlers = true }
		for key, _ in pairs(services) do
			assert(allowedServiceKeys[key], "services contains an invalid key: " .. tostring(key))
		end

		if services.bundlers ~= nil then
			assert(type(services.bundlers) == "table", "services.bundlers must be a table")

			assert(utils.lengthOfTable(services.bundlers) <= 20, "No more than 20 bundlers allowed")

			for _, bundler in ipairs(services.bundlers) do
				local allowedBundlerKeys = { fqdn = true, port = true, protocol = true, path = true }
				for key, _ in pairs(bundler) do
					assert(allowedBundlerKeys[key], "bundler contains an invalid key: " .. tostring(key))
				end
				assert(type(bundler.fqdn) == "string", "bundler.fqdn is required and must be a string")
				assert(
					type(bundler.port) == "number"
						and utils.isInteger(bundler.port)
						and bundler.port >= 0
						and bundler.port <= 65535,
					"bundler.port must be an integer between 0 and 65535"
				)
				assert(
					type(bundler.protocol) == "string" and bundler.protocol == "https",
					"bundler.protocol is required and must be 'https'"
				)
				assert(type(bundler.path) == "string", "bundler.path is required and must be a string")
			end
		end
	end
end

--- Updates the stats for a gateway
---@param address string # The address of the gateway to update stats for
---@param gateway table # The gateway object to update stats for
---@param stats table # The stats to update the gateway with
function gar.updateGatewayStats(address, gateway, stats)
	assert(gateway, "Gateway not found")
	assert(stats.prescribedEpochCount, "prescribedEpochCount is required")
	assert(stats.observedEpochCount, "observedEpochCount is required")
	assert(stats.totalEpochCount, "totalEpochCount is required")
	assert(stats.passedEpochCount, "passedEpochCount is required")
	assert(stats.failedEpochCount, "failedEpochCount is required")
	assert(stats.failedConsecutiveEpochs, "failedConsecutiveEpochs is required")
	assert(stats.passedConsecutiveEpochs, "passedConsecutiveEpochs is required")

	gateway.stats = stats
	GatewayRegistry[address] = gateway

	-- Schedule pruning if necessary
	if stats.failedConsecutiveEpochs >= gar.getSettings().operators.failedEpochCountMax then
		gar.scheduleNextGatewaysPruning(0)
	end

	return gateway
end

--- Updates the weights for a gateway
--- @param weightedGateway WeightedGateway The weighted gateway to update the weights for
function gar.updateGatewayWeights(weightedGateway)
	local address = weightedGateway.gatewayAddress
	-- by using the unsafe getGateway we avoid the need to update the GatewayRegistry global variable
	local gateway = gar.getGatewayUnsafe(address)
	assert(gateway, "Gateway not found")
	assert(weightedGateway.stakeWeight, "stakeWeight is required")
	assert(weightedGateway.tenureWeight, "tenureWeight is required")
	assert(weightedGateway.gatewayPerformanceRatio, "gatewayPerformanceRatio is required")
	assert(weightedGateway.observerPerformanceRatio, "observerPerformanceRatio is required")
	assert(weightedGateway.compositeWeight, "compositeWeight is required")
	assert(weightedGateway.normalizedCompositeWeight, "normalizedCompositeWeight is required")

	gateway.weights = {
		stakeWeight = weightedGateway.stakeWeight,
		tenureWeight = weightedGateway.tenureWeight,
		gatewayPerformanceRatio = weightedGateway.gatewayPerformanceRatio,
		observerPerformanceRatio = weightedGateway.observerPerformanceRatio,
		compositeWeight = weightedGateway.compositeWeight,
		normalizedCompositeWeight = weightedGateway.normalizedCompositeWeight,
	}
end

function gar.addGateway(address, gateway)
	GatewayRegistry[address] = gateway
	return gateway
end

--- @class PruneGatewaysResult
--- @field prunedGateways Gateway[] The pruned gateways
--- @field slashedGateways table<WalletAddress, number> The slashed gateways and their amounts
--- @field gatewayStakeReturned number The gateway stake returned
--- @field delegateStakeReturned number The delegate stake returned
--- @field gatewayStakeWithdrawing number The gateway stake withdrawing
--- @field delegateStakeWithdrawing number The delegate stake withdrawing
--- @field stakeSlashed number The stake slashed
--- @field gatewayObjectTallies GatewayObjectTallies|nil Statistics on the gateway system

--- Prunes gateways that have failed more than 30 consecutive epochs
--- @param currentTimestamp number The current timestamp
--- @param msgId string The message ID
--- @return PruneGatewaysResult # The result containing the pruned gateways, slashed gateways, and other stats
function gar.pruneGateways(currentTimestamp, msgId)
	--- @type PruneGatewaysResult
	local result = {
		prunedGateways = {},
		slashedGateways = {},
		gatewayStakeReturned = 0,
		delegateStakeReturned = 0,
		gatewayStakeWithdrawing = 0,
		delegateStakeWithdrawing = 0,
		stakeSlashed = 0,
	}
	if not NextGatewaysPruneTimestamp or currentTimestamp < NextGatewaysPruneTimestamp then
		-- No known pruning work to do
		return result
	end

	--- @type GatewayObjectTallies
	local gatewayObjectTallies = {
		numDelegates = 0,
		numDelegations = 0,
		numExitingDelegations = 0,
		numDelegateVaults = 0,
		numDelegatesVaulting = 0,
		numGatewayVaults = 0,
		numGatewaysVaulting = 0,
		numGateways = 0,
		numExitingGateways = 0,
	}

	-- we take a deep copy so we can operate directly on the gateway objects
	local gateways = gar.getGateways()
	local garSettings = gar.getSettings()

	if next(gateways) == nil then
		-- No pruning work to do going forward until next gateway joins
		NextGatewaysPruneTimestamp = nil
		return result
	end

	-- reset the next prune timestamp, below will populate it with the next prune timestamp minimum
	NextGatewaysPruneTimestamp = nil

	local uniqueDelegators = {}
	for gatewayAddress, gateway in pairs(gateways) do
		if gateway then
			gatewayObjectTallies.numGateways = gatewayObjectTallies.numGateways + 1
			-- first, return any expired vaults regardless of the gateway status
			for vaultId, vault in pairs(gateway.vaults) do
				if vault.endTimestamp <= currentTimestamp then
					unlockGatewayWithdrawVault(gateway, gatewayAddress, vaultId)

					result.gatewayStakeReturned = result.gatewayStakeReturned + vault.balance
				else
					-- find the next prune timestamp
					gar.scheduleNextGatewaysPruning(vault.endTimestamp)
					gatewayObjectTallies.numGatewayVaults = gatewayObjectTallies.numGatewayVaults + 1
				end
			end
			if next(gateway.vaults) ~= nil then
				gatewayObjectTallies.numGatewaysVaulting = gatewayObjectTallies.numGatewaysVaulting + 1
			end
			-- return any delegated vaults and return the stake to the delegate
			for delegateAddress, delegate in pairs(gateway.delegates) do
				for vaultId, vault in pairs(delegate.vaults) do
					if vault.endTimestamp <= currentTimestamp then
						unlockGatewayDelegateVault(gateway, delegateAddress, vaultId)
						result.delegateStakeReturned = result.delegateStakeReturned + vault.balance
					else
						-- find the next prune timestamp
						gar.scheduleNextGatewaysPruning(vault.endTimestamp)
						gatewayObjectTallies.numDelegateVaults = gatewayObjectTallies.numDelegateVaults + 1
					end
				end
				if next(delegate.vaults) ~= nil then
					gatewayObjectTallies.numDelegatesVaulting = gatewayObjectTallies.numDelegatesVaulting + 1
				end

				-- remove the delegate if all vaults are empty and the delegated stake is 0
				if delegate.delegatedStake == 0 and next(delegate.vaults) == nil then
					-- any allowlist reassignment would have already taken place by now
					gateway.delegates[delegateAddress] = nil
				elseif delegate.delegatedStake > 0 then
					gatewayObjectTallies.numDelegations = gatewayObjectTallies.numDelegations + 1
					if not uniqueDelegators[delegateAddress] then
						uniqueDelegators[delegateAddress] = true
						gatewayObjectTallies.numDelegates = gatewayObjectTallies.numDelegates + 1
					end
				else
					gatewayObjectTallies.numExitingDelegations = gatewayObjectTallies.numExitingDelegations + 1
				end
			end

			-- update the gateway before we do anything else
			GatewayRegistry[gatewayAddress] = gateway

			-- if gateway is joined but failed more than 30 consecutive epochs, mark it as leaving and put operator stake and delegate stakes in vaults
			if
				gateway.status == "joined"
				and garSettings ~= nil
				and gateway.stats.failedConsecutiveEpochs >= garSettings.operators.failedEpochCountMax
			then
				-- slash the minimum operator stake and return it to the protocol balance; mark the gateway as leaving which will vault remaining stake
				local slashableOperatorStake = math.min(gateway.operatorStake, garSettings.operators.minStake)
				local slashAmount = math.floor(slashableOperatorStake * garSettings.operators.failedGatewaySlashRate)
				result.delegateStakeWithdrawing = result.delegateStakeWithdrawing + gateway.totalDelegatedStake
				result.gatewayStakeWithdrawing = result.gatewayStakeWithdrawing + (gateway.operatorStake - slashAmount)
				gar.slashOperatorStake(gatewayAddress, slashAmount, currentTimestamp)
				gar.leaveNetwork(gatewayAddress, currentTimestamp, msgId)
				result.slashedGateways[gatewayAddress] = slashAmount
				result.stakeSlashed = result.stakeSlashed + slashAmount
				gatewayObjectTallies.numGateways = gatewayObjectTallies.numGateways - 1
				gatewayObjectTallies.numExitingGateways = gatewayObjectTallies.numExitingGateways + 1
			else
				if gateway.status == "leaving" then
					gatewayObjectTallies.numGateways = gatewayObjectTallies.numGateways - 1
					gatewayObjectTallies.numExitingGateways = gatewayObjectTallies.numExitingGateways + 1
					if gateway.endTimestamp ~= nil then
						if gateway.endTimestamp <= currentTimestamp then
							gatewayObjectTallies.numExitingGateways = gatewayObjectTallies.numExitingGateways - 1
							-- prune the gateway
							GatewayRegistry[gatewayAddress] = nil
							table.insert(result.prunedGateways, gatewayAddress)
						else
							-- find the next prune timestamp
							gar.scheduleNextGatewaysPruning(gateway.endTimestamp)
						end
					end
				end
			end
		end
	end

	result.gatewayObjectTallies = gatewayObjectTallies

	return result
end

function gar.slashOperatorStake(address, slashAmount, currentTimestamp)
	assert(utils.isInteger(slashAmount), "Slash amount must be an integer")
	assert(slashAmount > 0, "Slash amount must be greater than 0")

	local gateway = gar.getGateway(address)
	assert(gateway, "Gateway not found")
	local garSettings = gar.getSettings()
	assert(garSettings, "Gateway Registry settings do not exist")

	gateway.operatorStake = gateway.operatorStake - slashAmount
	gateway.slashings = gateway.slashings or {}
	gateway.slashings[tostring(currentTimestamp)] = slashAmount
	balances.increaseBalance(ao.id, slashAmount)
	GatewayRegistry[address] = gateway
end

---@param cursor string|nil # The cursor gateway address after which to fetch more gateways (optional)
---@param limit number # The max number of gateways to fetch
---@param sortBy string # The gateway field to sort by. Default is "gatewayAddress" (which is added each time)
---@param sortOrder string # The order to sort by, either "asc" or "desc"
---@return table # A table containing the paginated gateways and pagination metadata
function gar.getPaginatedGateways(cursor, limit, sortBy, sortOrder)
	local gateways = gar.getGateways()
	local gatewaysArray = {}
	local cursorField = "gatewayAddress" -- the cursor will be the gateway address
	for address, gateway in pairs(gateways) do
		--- @diagnostic disable-next-line: inject-field
		gateway.gatewayAddress = address
		-- remove delegates and vaults to avoid sending unbounded arrays, they can be fetched via getPaginatedDelegates and getPaginatedVaults
		gateway.delegates = nil
		gateway.vaults = nil
		table.insert(gatewaysArray, gateway)
	end

	return utils.paginateTableWithCursor(gatewaysArray, cursor, cursorField, limit, sortBy, sortOrder)
end

---@param address string # The address of the gateway
---@param cursor string|nil # The cursor delegate address after which to fetch more delegates (optional)
---@param limit number # The max number of delegates to fetch
---@param sortBy string # The delegate field to sort by. Default is "address" (which is added each)
---@param sortOrder string # The order to sort by, either "asc" or "desc"
---@return table # A table containing the paginated delegates and pagination metadata
function gar.getPaginatedDelegates(address, cursor, limit, sortBy, sortOrder)
	local gateway = gar.getGateway(address)
	assert(gateway, "Gateway not found")
	local delegatesArray = {}
	local cursorField = "address"
	for delegateAddress, delegate in pairs(gateway.delegates) do
		--- @diagnostic disable-next-line: inject-field
		delegate.address = delegateAddress
		delegate.vaults = nil -- remove vaults to avoid sending an unbounded array, we can fetch them if needed via getPaginatedDelegations
		table.insert(delegatesArray, delegate)
	end

	return utils.paginateTableWithCursor(delegatesArray, cursor, cursorField, limit, sortBy, sortOrder)
end

--- Returns all allowed delegates if allowlisting is in use. Empty table otherwise.
---@param address string # The address of the gateway
---@param cursor string|nil # The cursor delegate address after which to fetch more delegates (optional)
---@param limit number # The max number of delegates to fetch
---@param sortOrder string # The order to sort by, either "asc" or "desc"
---@return table # A table containing the paginated allowed delegates and pagination metadata
function gar.getPaginatedAllowedDelegates(address, cursor, limit, sortOrder)
	local gateway = gar.getGateway(address)
	assert(gateway, "Gateway not found")
	local allowedDelegatesArray = {}

	if gateway.settings.allowedDelegatesLookup then
		for delegateAddress, _ in pairs(gateway.settings.allowedDelegatesLookup) do
			table.insert(allowedDelegatesArray, delegateAddress)
		end
		for delegateAddress, delegate in pairs(gateway.delegates) do
			if delegate.delegatedStake > 0 then
				table.insert(allowedDelegatesArray, delegateAddress)
			end
		end
	end

	local cursorField = nil
	local sortBy = nil
	return utils.paginateTableWithCursor(allowedDelegatesArray, cursor, cursorField, limit, sortBy, sortOrder)
end

function gar.cancelGatewayWithdrawal(from, gatewayAddress, vaultId)
	local gateway = gar.getGateway(gatewayAddress)
	assert(gateway, "Gateway not found")

	assert(gateway.status ~= "leaving", "Gateway is leaving the network and cannot cancel withdrawals.")

	local existingVault, delegate
	local isGatewayWithdrawal = from == gatewayAddress
	-- if the from matches the gateway address, we are cancelling the operator withdrawal
	if isGatewayWithdrawal then
		existingVault = gateway.vaults[vaultId]
	else
		delegate = gateway.delegates[from]
		assert(delegate, "Delegate not found")
		existingVault = delegate.vaults[vaultId]
	end

	assert(existingVault, "Vault not found for " .. from .. " on " .. gatewayAddress)

	-- confirm the gateway still allow staking
	assert(isGatewayWithdrawal or gateway.settings.allowDelegatedStaking, "Gateway does not allow staking")

	local previousOperatorStake = gateway.operatorStake
	local previousTotalDelegatedStake = gateway.totalDelegatedStake
	local vaultBalance = existingVault.balance
	if isGatewayWithdrawal then
		cancelGatewayWithdrawVault(gateway, vaultId)
	else
		cancelGatewayDelegateVault(gateway, from, vaultId)
	end
	GatewayRegistry[gatewayAddress] = gateway
	return {
		previousOperatorStake = previousOperatorStake,
		previousTotalDelegatedStake = previousTotalDelegatedStake,
		totalOperatorStake = gateway.operatorStake,
		totalDelegatedStake = gateway.totalDelegatedStake,
		vaultBalance = vaultBalance,
		gateway = gateway,
	}
end

---@param from string # The address of the operator or delegate
---@param gatewayAddress string # The address of the gateway
---@param vaultId string # The id of the vault
---@param currentTimestamp number # The current timestamp
---@return table # A table containing the gateway, elapsed time, remaining time, penalty rate, expedited withdrawal fee, and amount withdrawn
function gar.instantGatewayWithdrawal(from, gatewayAddress, vaultId, currentTimestamp)
	local gateway = gar.getGateway(gatewayAddress)
	assert(gateway, "Gateway not found")

	local isGatewayWithdrawal = from == gatewayAddress
	assert(gateway.status ~= "leaving", "This gateway is leaving and this vault cannot be instantly withdrawn.")

	local vault
	local delegate
	if isGatewayWithdrawal then
		vault = gateway.vaults[vaultId]
	else
		delegate = gateway.delegates[from]
		assert(delegate, "Delegate not found")
		vault = delegate.vaults[vaultId]
	end
	assert(vault, "Vault not found")

	---@type number
	local elapsedTime = currentTimestamp - vault.startTimestamp
	---@type number
	local totalWithdrawalTime = vault.endTimestamp - vault.startTimestamp

	-- Ensure the elapsed time is not negative
	assert(elapsedTime >= 0, "Invalid elapsed time")

	-- Process the instant withdrawal
	local expeditedWithdrawalFee, amountToWithdraw, penaltyRate =
		processInstantWithdrawal(vault.balance, elapsedTime, totalWithdrawalTime, from)

	-- Remove the vault after withdrawal
	if isGatewayWithdrawal then
		gateway.vaults[vaultId] = nil
	else
		assert(delegate, "Delegate not found")
		delegate.vaults[vaultId] = nil
		-- Remove the delegate if no stake is left
		if delegate.delegatedStake == 0 and next(delegate.vaults) == nil then
			gar.pruneDelegateFromGatewayIfNecessary(from, gateway)
		end
	end

	-- Update the gateway
	GatewayRegistry[gatewayAddress] = gateway
	return {
		gateway = gateway,
		elapsedTime = elapsedTime,
		remainingTime = totalWithdrawalTime - elapsedTime,
		penaltyRate = penaltyRate,
		expeditedWithdrawalFee = expeditedWithdrawalFee,
		amountWithdrawn = amountToWithdraw,
	}
end

--- Preserves delegate's position in allow list upon removal from gateway
--- @param delegateAddress string The address of the delegator
--- @param gateway table The gateway from which the delegate is being removed
--- @return boolean # Whether or not the delegate was pruned
function gar.pruneDelegateFromGatewayIfNecessary(delegateAddress, gateway)
	local pruned = false
	local delegate = gateway.delegates[delegateAddress]
	if delegate.delegatedStake == 0 and utils.lengthOfTable(delegate.vaults) == 0 then
		gateway.delegates[delegateAddress] = nil
		pruned = true

		-- replace the delegate in the allowedDelegatesLookup table if necessary
		if gateway.settings.allowedDelegatesLookup then
			gateway.settings.allowedDelegatesLookup[delegateAddress] = true
		end
	end
	return pruned
end

--- Add delegate addresses to the allowedDelegatesLookup table in the gateway's settings
--- @param delegateAddresses table The list of delegate addresses to add
--- @param gatewayAddress string The address of the gateway
--- @return table result Result table containing updated gateway object and the delegates that were actually added
function gar.allowDelegates(delegateAddresses, gatewayAddress)
	local gateway = gar.getGateway(gatewayAddress)
	assert(gateway, "Gateway not found")

	-- Only allow modification of the allow list when allowDelegatedStaking is set to false or a current allow list is in place
	assert(
		not gateway.settings.allowDelegatedStaking or gateway.settings.allowedDelegatesLookup,
		"Allow listing only possible when allowDelegatedStaking is set to 'allowlist'"
	)

	assert(gateway.settings.allowedDelegatesLookup, "allowedDelegatesLookup should not be nil")

	local addedDelegates = {}
	for _, delegateAddress in ipairs(delegateAddresses) do
		assert(utils.isValidAddress(delegateAddress, true), "Invalid delegate address: " .. delegateAddress)
		-- Skip over delegates that are already in the allow list or that have a stake balance
		if not gar.delegateAllowedToStake(delegateAddress, gateway) then
			gateway.settings.allowedDelegatesLookup[delegateAddress] = true
			table.insert(addedDelegates, delegateAddress)
		end
	end

	GatewayRegistry[gatewayAddress] = gateway
	return {
		gateway = gateway,
		addedDelegates = addedDelegates,
	}
end

function gar.isEligibleForArNSDiscount(from)
	local gateway = gar.getGatewayUnsafe(from)
	if gateway == nil or gateway.weights == nil or gar.isGatewayLeaving(gateway) then
		return false
	end

	local tenureWeight = gateway.weights.tenureWeight or 0
	local gatewayPerformanceRatio = gateway.weights.gatewayPerformanceRatio or 0

	return tenureWeight >= constants.GATEWAY_OPERATOR_ARNS_DISCOUNT_TENURE_WEIGHT_ELIGIBILITY_THRESHOLD
		and gatewayPerformanceRatio
			>= constants.GATEWAY_OPERATOR_ARNS_DISCOUNT_PERFORMANCE_RATIO_ELIGIBILITY_THRESHOLD
end

--- Remove delegate addresses from the allowedDelegatesLookup table in the gateway's settings
--- @param delegates WalletAddress[] The list of delegate addresses to remove
--- @param gatewayAddress WalletAddress The address of the gateway
--- @param msgId MessageId The associated message ID
--- @param currentTimestamp Timestamp The current timestamp
--- @return table result Result table containing updated gateway object and the delegates that were actually removed
function gar.disallowDelegates(delegates, gatewayAddress, msgId, currentTimestamp)
	local gateway = gar.getGateway(gatewayAddress)
	assert(gateway, "Gateway not found")

	-- Only allow modification of the allow list when allowDelegatedStaking is set to false or a current allow list is in place
	assert(
		not gateway.settings.allowDelegatedStaking or gateway.settings.allowedDelegatesLookup,
		"Allow listing only possible when allowDelegatedStaking is set to 'allowlist'"
	)

	assert(gateway.settings.allowedDelegatesLookup, "allowedDelegatesLookup should not be nil")

	local removedDelegates = {}
	for _, delegateToDisallow in ipairs(delegates) do
		assert(utils.isValidAddress(delegateToDisallow, true), "Invalid delegate address: " .. delegateToDisallow)

		-- Skip over delegates that are not in the allow list
		if gateway.settings.allowedDelegatesLookup[delegateToDisallow] then
			gateway.settings.allowedDelegatesLookup[delegateToDisallow] = nil
			table.insert(removedDelegates, delegateToDisallow)
		end
		-- Kick the delegate off the gateway if necessary
		local ban = true
		gar.kickDelegateFromGateway(delegateToDisallow, gateway, msgId, currentTimestamp, ban)
	end

	GatewayRegistry[gatewayAddress] = gateway
	return {
		gateway = gateway,
		removedDelegates = removedDelegates,
	}
end

--- Vaults delegate's tokens and updates delegate and gateway staking balances
--- @param delegateAddress string The address of the delegator
--- @param gateway Gateway The gateway from which to kick the delegate
--- @param msgId MessageId The currently message ID
--- @param currentTimestamp number The current timestamp
--- @param ban boolean|nil Prevents adding the delegate back to the allowlist
function gar.kickDelegateFromGateway(delegateAddress, gateway, msgId, currentTimestamp, ban)
	local delegate = gateway.delegates[delegateAddress]
	if not delegate then
		return
	end

	if not delegate.vaults then
		delegate.vaults = {}
	end

	local remainingStake = delegate.delegatedStake
	if remainingStake > 0 then
		createDelegateWithdrawVault(gateway, delegateAddress, msgId, remainingStake, currentTimestamp)
	end
	decreaseDelegateStakeAtGateway(delegateAddress, gateway, remainingStake, ban)
end

function gar.delegationAllowlistedOnGateway(gateway)
	return gateway.settings.allowedDelegatesLookup ~= nil
end

function gar.delegateAllowedToStake(delegateAddress, gateway)
	if not gar.delegationAllowlistedOnGateway(gateway) then
		return true
	end
	-- Delegate must either be in the allow list or have a balance greater than 0
	return gateway.settings.allowedDelegatesLookup[delegateAddress]
		or (gateway.delegates[delegateAddress] and gateway.delegates[delegateAddress].delegatedStake or 0) > 0
end

--- @alias VaultId string
--- @alias GatewayAddress WalletAddress

--- @class StakeSpendingPlan
--- @field delegatedStake number
--- @field vaults table<VaultId, number>

--- @class FundingPlan
--- @field address WalletAddress
--- @field balance number
--- @field stakes table<GatewayAddress, StakeSpendingPlan>
--- @field shortfall number

--- @param address WalletAddress the funder of the funding plan
--- @param quantity number the amount the funding plan aims to satisfy
--- @param sourcesPreference "any"|"balance"|"stakes" the allowed funding sources
--- @return FundingPlan
function gar.getFundingPlan(address, quantity, sourcesPreference)
	sourcesPreference = sourcesPreference or "balance"
	local fundingPlan = {
		address = address,
		balance = 0,
		stakes = {},
		shortfall = quantity,
	}

	planBalanceDrawdown(fundingPlan, sourcesPreference)

	-- early return if possible. Otherwise we'll move on to using withdraw vaults
	if fundingPlan.shortfall == 0 or sourcesPreference == "balance" then
		return fundingPlan
	end

	local stakingProfile = planVaultsDrawdown(fundingPlan)

	-- early return if possible. Otherwise we'll move on to use excess stakes
	if fundingPlan.shortfall == 0 then
		return fundingPlan
	end

	planExcessStakesDrawdown(fundingPlan, stakingProfile)

	-- early return if possible. Otherwise we'll move on to using minimum stakes
	if fundingPlan.shortfall == 0 then
		return fundingPlan
	end

	planMinimumStakesDrawdown(fundingPlan, stakingProfile)

	return fundingPlan
end

function planBalanceDrawdown(fundingPlan, sourcesPreference)
	local availableBalance = balances.getBalance(fundingPlan.address)
	if sourcesPreference == "balance" or sourcesPreference == "any" then
		fundingPlan.balance = math.min(availableBalance, fundingPlan.shortfall)
		fundingPlan.shortfall = fundingPlan.shortfall - fundingPlan.balance
	end
end

function getStakingProfile(address)
	return utils.sortTableByFields(
		utils.reduce(
			-- only consider gateways that have the address as a delegate
			utils.filterDictionary(gar.getGatewaysUnsafe(), function(_, gateway)
				return gateway.delegates[address] ~= nil
			end),
			-- extract only the essential gateway fields, copying tables so we don't mutate references
			function(acc, gatewayAddress, gateway)
				local totalEpochsGatewayPassed = gateway.stats.passedEpochCount or 0
				local totalEpochsParticipatedIn = gateway.stats.totalEpochCount or 0
				local gatewayPerformanceRatio = (1 + totalEpochsGatewayPassed) / (1 + totalEpochsParticipatedIn)
				local delegate = utils.deepCopy(gateway.delegates[address])
				delegate.excessStake = math.max(0, delegate.delegatedStake - gateway.settings.minDelegatedStake)
				delegate.gatewayAddress = gatewayAddress
				table.insert(acc, {
					totalDelegatedStake = gateway.totalDelegatedStake, -- for comparing gw total stake
					gatewayPerformanceRatio = gatewayPerformanceRatio, -- for comparing gw performance
					delegate = delegate,
					startTimestamp = gateway.startTimestamp, -- for comparing gw tenure
				})
				return acc
			end,
			{}
		),
		{
			{
				order = "desc",
				field = "delegate.excessStake",
			},
			{
				order = "asc",
				field = "gatewayPerformanceRatio",
			},
			{
				order = "desc",
				field = "totalDelegatedStake",
			},
			{
				order = "desc",
				field = "startTimestamp",
			},
		}
	)
end

function planVaultsDrawdown(fundingPlan)
	-- find all the address's delegations across the gateways
	local stakingProfile = getStakingProfile(fundingPlan.address)

	-- simulate drawing down vaults until the remaining balance is satisfied OR vaults are exhausted
	local vaults = utils.sortTableByFields(
		-- flatten the vaults across all gateways so we can sort them together
		utils.reduce(stakingProfile, function(acc, _, gatewayInfo)
			for vaultId, vault in pairs(gatewayInfo.delegate.vaults) do
				table.insert(acc, {
					vaultId = vaultId,
					gatewayAddress = gatewayInfo.delegate.gatewayAddress,
					endTimestamp = vault.endTimestamp,
					balance = vault.balance,
				})
			end
			return acc
		end, {}),
		{
			{
				order = "asc",
				field = "endTimestamp",
			},
		}
	)

	for _, vault in pairs(vaults) do
		if fundingPlan.shortfall == 0 then
			break
		end
		local balance = vault.balance
		local balanceToDraw = math.min(balance, fundingPlan.shortfall)
		local gatewayAddress = vault.gatewayAddress
		if balanceToDraw > 0 then
			if not fundingPlan["stakes"][gatewayAddress] then
				fundingPlan["stakes"][gatewayAddress] = {
					delegatedStake = 0,
					vaults = {},
				}
			end
			fundingPlan["stakes"][gatewayAddress].vaults[vault.vaultId] = balanceToDraw
			fundingPlan.shortfall = fundingPlan.shortfall - balanceToDraw
			vault.balance = balance - balanceToDraw
		end
	end

	return stakingProfile
end

function planExcessStakesDrawdown(fundingPlan, stakingProfile)
	-- simulate drawing down excess stakes until the remaining balance is satisfied OR excess stakes are exhausted
	for _, gatewayInfo in pairs(stakingProfile) do
		if fundingPlan.shortfall == 0 then
			break
		end
		local excessStake = gatewayInfo.delegate.excessStake
		local stakeToDraw = math.min(excessStake, fundingPlan.shortfall)
		if stakeToDraw > 0 then
			if not fundingPlan["stakes"][gatewayInfo.delegate.gatewayAddress] then
				fundingPlan["stakes"][gatewayInfo.delegate.gatewayAddress] = {
					delegatedStake = 0,
					vaults = {},
				}
			end
			fundingPlan["stakes"][gatewayInfo.delegate.gatewayAddress].delegatedStake = stakeToDraw
			fundingPlan.shortfall = fundingPlan.shortfall - stakeToDraw
			gatewayInfo.delegate.delegatedStake = gatewayInfo.delegate.delegatedStake - stakeToDraw
			-- maintain consistency for future re-sorting of the gatewayInfos based on theoretical updated state
			gatewayInfo.delegate.excessStake = excessStake - stakeToDraw
			gatewayInfo.totalDelegatedStake = gatewayInfo.totalDelegatedStake - stakeToDraw
		end
	end
	return stakingProfile
end

function planMinimumStakesDrawdown(fundingPlan, stakingProfile)
	-- re-sort the gateways since their totalDelegatedStakes may have changed
	stakingProfile = utils.sortTableByFields(stakingProfile, {
		{
			order = "asc",
			field = "gatewayPerformanceRatio",
		},
		{
			order = "desc",
			field = "totalDelegatedStake",
		},
		{
			order = "desc",
			field = "startTimestamp",
		},
	})

	for _, gatewayInfo in pairs(stakingProfile) do
		if fundingPlan.shortfall == 0 then
			break
		end

		local stakeToDraw = math.min(gatewayInfo.delegate.delegatedStake, fundingPlan.shortfall)
		if stakeToDraw > 0 then
			if not fundingPlan["stakes"][gatewayInfo.delegate.gatewayAddress] then
				fundingPlan["stakes"][gatewayInfo.delegate.gatewayAddress] = {
					delegatedStake = 0,
					vaults = {},
				}
			end
			fundingPlan["stakes"][gatewayInfo.delegate.gatewayAddress].delegatedStake = fundingPlan["stakes"][gatewayInfo.delegate.gatewayAddress].delegatedStake
				+ stakeToDraw
			fundingPlan.shortfall = fundingPlan.shortfall - stakeToDraw
			-- not needed after this, but keep track
			gatewayInfo.delegate.delegatedStake = gatewayInfo.delegate.delegatedStake - stakeToDraw
			gatewayInfo.totalDelegatedStake = gatewayInfo.totalDelegatedStake - stakeToDraw
		end
	end
end

--- Reduces all balances and creates withdraw stakes as prescribed by the funding plan
--- @param fundingPlan table The funding plan to apply
--- @param msgId string The current message ID
--- @param currentTimestamp number The current timestamp
function gar.applyFundingPlan(fundingPlan, msgId, currentTimestamp)
	local appliedPlan = {
		totalFunded = 0,
		newWithdrawVaults = {},
	}

	-- draw down balance first
	if fundingPlan.balance > 0 then
		balances.reduceBalance(fundingPlan.address, fundingPlan.balance)
		appliedPlan.totalFunded = appliedPlan.totalFunded + fundingPlan.balance
	end

	--draw down stakes and vaults, creating withdraw vaults if necessary
	for gatewayAddress, delegationPlan in pairs(fundingPlan.stakes) do
		local gateway = gar.getGateway(gatewayAddress)
		assert(gateway, "Gateway not found")
		local delegate = gateway.delegates[fundingPlan.address]
		assert(delegate, "Delegate not found")

		-- draw down the vaults first so that allowlisting logic will work correctly when drawing down balances
		delegate.vaults = utils.reduce(delegate.vaults, function(acc, vaultId, vault)
			if delegationPlan.vaults[vaultId] then
				-- if the whole vault is used, "prune" it by moving on
				if vault.balance ~= delegationPlan.vaults[vaultId] then
					acc[vaultId] = {
						balance = vault.balance - delegationPlan.vaults[vaultId],
						startTimestamp = vault.startTimestamp,
						endTimestamp = vault.endTimestamp,
					}
					gar.scheduleNextGatewaysPruning(vault.endTimestamp)
					assert(acc[vaultId].balance > 0, "Vault balance should be greater than 0")
				end
				appliedPlan.totalFunded = appliedPlan.totalFunded + delegationPlan.vaults[vaultId]
			else
				-- nothing to change
				acc[vaultId] = vault
			end
			return acc
		end, {})

		-- draw down the delegated stake balance
		assert(delegate.delegatedStake - delegationPlan.delegatedStake >= 0, "Delegated stake cannot be negative")
		assert(
			gateway.totalDelegatedStake - delegationPlan.delegatedStake >= 0,
			"Total delegated stake cannot be negative"
		)
		decreaseDelegateStakeAtGateway(fundingPlan.address, gateway, delegationPlan.delegatedStake)
		appliedPlan.totalFunded = appliedPlan.totalFunded + delegationPlan.delegatedStake

		-- create an exit vault for the remaining stake if less than the gateway's minimum
		if delegate.delegatedStake > 0 and delegate.delegatedStake < gateway.settings.minDelegatedStake then
			createDelegateWithdrawVault(gateway, fundingPlan.address, msgId, delegate.delegatedStake, currentTimestamp)
			decreaseDelegateStakeAtGateway(fundingPlan.address, gateway, delegate.delegatedStake)
			appliedPlan.newWithdrawVaults[gatewayAddress] = {
				[msgId] = utils.deepCopy(delegate.vaults[msgId]),
			}
		end

		-- update the gateway
		GatewayRegistry[gatewayAddress] = gateway
	end

	return appliedPlan
end

--- Fetch copies of all the delegations present across all gateways for the given address
--- @param address string The address of the delegator
--- @return table # a table, indexed by gateway address, of all the address's delegations, including nested vaults
function gar.getDelegations(address)
	return utils.reduce(gar.getGatewaysUnsafe(), function(acc, gatewayAddress, gateway)
		if gateway.delegates[address] then
			acc[gatewayAddress] = utils.deepCopy(gateway.delegates[address])
		end
		return acc
	end, {})
end

--- If delegate is missing or stake is 0, then not eligible for distributions
--- @param gateway table The gateway to check
--- @param delegateAddress string The address of the delegate to check
--- @return boolean isEligible - whether the delegate is eligible for distributions
function gar.isDelegateEligibleForDistributions(gateway, delegateAddress)
	return gateway.delegates[delegateAddress] and gateway.delegates[delegateAddress].delegatedStake > 0
end

---@class Delegation
---@field type string # The type of the object. Either "stake" or "vault"
---@field gatewayAddress string # The address of the gateway the delegation is associated with
---@field delegateStake number|nil # The amount of stake delegated to the gateway if type is "stake"
---@field startTimestamp number # The start timestamp of the delegation's initial stake or the vault's creation
---@field messageId string|nil # The message ID associated with the vault's creation if type is "vault"
---@field balance number|nil # The balance of the vault if type is "vault"
---@field endTimestamp number|nil # The end timestamp of the vault if type is "vault"
---@field delegationId string # The unique ID of the delegation

--- Fetch a flattened array of all the delegations (stakes and vaults) present across all gateways for the given address
--- @param address string The address of the delegator
--- @return Delegation[] # A table of all the address's staked and vaulted delegations
function gar.getFlattenedDelegations(address)
	return utils.reduce(gar.getDelegations(address), function(acc, gatewayAddress, delegation)
		table.insert(acc, {
			type = "stake",
			gatewayAddress = gatewayAddress,
			balance = delegation.delegatedStake,
			startTimestamp = delegation.startTimestamp,
			delegationId = gatewayAddress .. "_" .. delegation.startTimestamp,
		})
		for vaultId, vault in pairs(delegation.vaults) do
			table.insert(acc, {
				type = "vault",
				gatewayAddress = gatewayAddress,
				startTimestamp = vault.startTimestamp,
				vaultId = vaultId,
				balance = vault.balance,
				endTimestamp = vault.endTimestamp,
				delegationId = gatewayAddress .. "_" .. vault.startTimestamp,
			})
		end
		return acc
	end, {})
end

--- Fetch a heterogenous array of all active and vaulted delegated stakes, cursored on startTimestamp
--- @param address string The address of the delegator
--- @param cursor string|number|nil The cursor after which to fetch more stakes (optional)
--- @param limit number The max number of stakes to fetch
--- @param sortBy string The field to sort by. Default is "startTimestamp"
--- @param sortOrder string The order to sort by, either "asc" or "desc". Default is "asc"
--- @return PaginatedTable # A table containing the paginated stakes and pagination metadata as Delegation objects
function gar.getPaginatedDelegations(address, cursor, limit, sortBy, sortOrder)
	local delegationsArray = gar.getFlattenedDelegations(address)
	return utils.paginateTableWithCursor(
		delegationsArray,
		cursor,
		"delegationId",
		limit,
		sortBy or "startTimestamp",
		sortOrder or "asc"
	)
end

--- @type { [string]: { timestamp: number, redelegations: number } }
Redelegations = Redelegations or {}

function gar.pruneRedelegationFeeData(currentTimestamp)
	local delegatorsWithFeesReset = {}
	if not NextRedelegationsPruneTimestamp or currentTimestamp < NextRedelegationsPruneTimestamp then
		-- No known pruning work to do
		return delegatorsWithFeesReset
	end

	local pruningThreshold = currentTimestamp
		- constants.DEFAULT_GAR_SETTINGS.redelegations.redelegationFeeResetIntervalMs

	-- reset the next prune timestamp, below will populate it with the next prune timestamp minimum
	NextRedelegationsPruneTimestamp = nil

	Redelegations = utils.reduce(gar.getRedelgationsUnsafe(), function(acc, delegateAddress, redelegationData)
		if redelegationData.timestamp > pruningThreshold then
			acc[delegateAddress] = redelegationData
			gar.scheduleNextRedelegationsPruning(
				redelegationData.timestamp + constants.DEFAULT_GAR_SETTINGS.redelegations.redelegationFeeResetIntervalMs
			)
		else
			table.insert(delegatorsWithFeesReset, delegateAddress)
		end
		return acc
	end, {})

	return delegatorsWithFeesReset
end

function gar.getRedelgations()
	return utils.deepCopy(Redelegations)
end

function gar.getRedelgationsUnsafe()
	return Redelegations
end

function gar.getRedelegation(delegateAddress)
	return gar.getRedelgations()[delegateAddress]
end

function gar.getRedelegationUnsafe(delegateAddress)
	return gar.getRedelgationsUnsafe()[delegateAddress]
end

--- @class RedelegateStakeParams
--- @field delegateAddress string # The address of the delegate to redelegate stake from (required)
--- @field sourceAddress string # The address of the gateway to redelegate stake from (required)
--- @field targetAddress string # The address of the gateway to redelegate stake to (required)
--- @field qty number # The amount of stake to redelegate - must be positive integer (required)
--- @field currentTimestamp number # The current timestamp (required)
--- @field vaultId string | nil # The vault id to redelegate from (optional)

--- @class RedelegateStakeResult
--- @field sourceAddress WalletAddress # The address of the gateway that the stake was moved from
--- @field targetAddress table # The address of the gateway that the stake was moved to
--- @field redelegationFee number # The fee charged for the redelegation
--- @field feeResetTimestamp number # The timestamp when the redelegation fee will be reset
--- @field redelegationsSinceFeeReset number # The number of redelegations the user has made since the last fee reset

--- Take stake from a delegate and stake it to a new delegate.
--- This function will be called by the delegate to redelegate their stake to a new gateway.
--- The delegated stake will be moved from the old gateway to the new gateway.
--- It will fail if there is no or not enough delegated stake to move from the gateway.
--- It will fail if the old gateway does not meet the minimum staking requirements after the stake is moved.
--- It can move stake from the vaulted stake
--- It can move stake from its own stake as long as it meets the minimum staking requirements after the stake is moved.
--- @param params RedelegateStakeParams
--- @return RedelegateStakeResult
function gar.redelegateStake(params)
	local delegateAddress = params.delegateAddress
	local targetAddress = params.targetAddress
	local sourceAddress = params.sourceAddress
	local stakeToTakeFromSource = params.qty
	local currentTimestamp = params.currentTimestamp
	local vaultId = params.vaultId

	assert(type(stakeToTakeFromSource) == "number", "Quantity is required and must be a number")
	assert(stakeToTakeFromSource > 0, "Quantity must be greater than 0")
	assert(utils.isValidAddress(targetAddress, true), "Target address is required and must be a string")
	assert(utils.isValidAddress(sourceAddress, true), "Source address is required and must be a string")
	assert(utils.isValidAddress(delegateAddress, true), "Delegate address is required and must be a string")
	assert(type(currentTimestamp) == "number", "Current timestamp is required and must be a number")
	assert(sourceAddress ~= targetAddress, "Source and target gateway addresses must be different.")

	local sourceGateway = gar.getGateway(sourceAddress)
	local targetGateway = gar.getGateway(targetAddress)

	assert(sourceGateway, "Source Gateway not found")
	assert(targetGateway, "Target Gateway not found")
	assert(
		targetGateway.status ~= "leaving",
		"Target Gateway is leaving the network and cannot have more stake delegated to it."
	)
	assert(targetGateway.settings.allowDelegatedStaking, "Target Gateway does not allow delegated staking.")
	assert(
		gar.delegateAllowedToStake(delegateAddress, targetGateway),
		"This Gateway does not allow this delegate to stake."
	)

	local redelegationFeeRate = gar.getRedelegationFee(delegateAddress).redelegationFeeRate
	local redelegationFee = math.ceil(stakeToTakeFromSource * (redelegationFeeRate / 100))
	local stakeToDelegate = stakeToTakeFromSource - redelegationFee

	assert(stakeToDelegate > 0, "The redelegation stake amount minus the redelegation fee is too low to redelegate.")

	-- Assert source has enough stake to redelegate and remove the stake from the source
	if delegateAddress == sourceAddress then
		-- check if the gateway can afford to redelegate from itself

		if vaultId then
			-- Get the redelegation amount from the operator vault

			local existingVault = sourceGateway.vaults[vaultId]
			assert(existingVault, "Vault not found on the operator.")
			assert(
				existingVault.balance >= stakeToTakeFromSource,
				"Quantity must be less than or equal to the vaulted stake amount."
			)

			reduceStakeFromGatewayVault(sourceGateway, stakeToTakeFromSource, vaultId)
		else
			-- Get the redelegation amount from the operator stakes
			local maxWithdraw = sourceGateway.operatorStake - gar.getSettings().operators.minStake
			assert(
				stakeToTakeFromSource <= maxWithdraw,
				"Resulting stake of "
					.. sourceGateway.operatorStake - stakeToTakeFromSource
					.. " mARIO is not enough to maintain the minimum operator stake of "
					.. gar.getSettings().operators.minStake
					.. " mARIO"
			)

			sourceGateway.operatorStake = sourceGateway.operatorStake - stakeToTakeFromSource
		end
	else
		local existingDelegate = sourceGateway.delegates[delegateAddress]
		assert(existingDelegate, "This delegate has no stake to redelegate.")

		if vaultId then
			local existingVault = existingDelegate.vaults[vaultId]
			assert(existingVault, "Vault not found on the delegate.")
			assert(
				existingVault.balance >= stakeToTakeFromSource,
				"Quantity must be less than or equal to the vaulted stake amount."
			)

			reduceStakeFromDelegateVault(sourceGateway, delegateAddress, stakeToTakeFromSource, vaultId)
		else
			-- Check if the delegate has enough stake to redelegate
			assert(
				existingDelegate.delegatedStake >= stakeToTakeFromSource,
				"Quantity must be less than or equal to the delegated stake amount."
			)

			-- Check if the delegate will have enough stake left after re-delegating
			local existingStake = existingDelegate.delegatedStake
			local requiredMinimumStake = sourceGateway.settings.minDelegatedStake
			local maxAllowedToWithdraw = existingStake - requiredMinimumStake
			assert(
				stakeToTakeFromSource <= maxAllowedToWithdraw or stakeToTakeFromSource == existingStake,
				"Remaining delegated stake must be greater than the minimum delegated stake. Adjust the amount or re-delegate all stake."
			)
			decreaseDelegateStakeAtGateway(delegateAddress, sourceGateway, stakeToTakeFromSource)
		end
	end

	-- The stake can now be applied to the targetGateway
	if targetAddress == delegateAddress then
		-- move the stake to the operator's stake
		targetGateway.operatorStake = targetGateway.operatorStake + stakeToDelegate
	else
		local existingTargetDelegate = targetGateway.delegates[delegateAddress]
		local minimumStakeForGatewayAndDelegate
		if existingTargetDelegate and existingTargetDelegate.delegatedStake ~= 0 then
			-- It already has a stake that is not zero
			minimumStakeForGatewayAndDelegate = 1 -- Delegate must provide at least one additional mARIO
		else
			-- Consider if the operator increases the minimum amount after you've already staked
			minimumStakeForGatewayAndDelegate = targetGateway.settings.minDelegatedStake
		end

		-- Check if the delegate has enough stake to redelegate
		assert(
			stakeToDelegate >= minimumStakeForGatewayAndDelegate,
			"Quantity must be greater than the minimum delegated stake amount."
		)

		targetGateway.delegates[delegateAddress] = targetGateway.delegates[delegateAddress]
			or gar.createDelegateAtGateway(currentTimestamp, targetGateway, delegateAddress)
		increaseDelegateStakeAtGateway(targetGateway.delegates[delegateAddress], targetGateway, stakeToDelegate)
	end

	-- Move redelegation fee to protocol balance
	balances.increaseBalance(ao.id, redelegationFee)

	local previousRedelegations = gar.getRedelegation(delegateAddress)
	local redelegationsSinceFeeReset = (previousRedelegations and previousRedelegations.redelegations or 0) + 1

	-- update the source and target gateways, and the delegator's redelegation fee data
	GatewayRegistry[sourceAddress] = sourceGateway
	GatewayRegistry[targetAddress] = targetGateway
	Redelegations[delegateAddress] = {
		timestamp = currentTimestamp,
		redelegations = redelegationsSinceFeeReset,
	}
	gar.scheduleNextRedelegationsPruning(
		currentTimestamp + constants.DEFAULT_GAR_SETTINGS.redelegations.redelegationFeeResetIntervalMs
	)

	return {
		sourceAddress = sourceAddress,
		targetAddress = targetAddress,
		redelegationFee = redelegationFee,
		feeResetTimestamp = currentTimestamp
			+ constants.DEFAULT_GAR_SETTINGS.redelegations.redelegationFeeResetIntervalMs,
		redelegationsSinceFeeReset = redelegationsSinceFeeReset,
	}
end

function gar.getRedelegationFee(delegateAddress)
	local previousRedelegations = gar.getRedelegationUnsafe(delegateAddress)

	local previousRedelegationCount = previousRedelegations and previousRedelegations.redelegations or 0
	--- first one is free, max of 60%
	local redelegationFeeRate = math.min(10 * previousRedelegationCount, 60)

	local lastRedelegationTimestamp = previousRedelegations and previousRedelegations.timestamp or nil
	local feeResetTimestamp = lastRedelegationTimestamp
			and lastRedelegationTimestamp + constants.DEFAULT_GAR_SETTINGS.redelegations.redelegationFeeResetIntervalMs
		or nil

	return {
		redelegationFeeRate = redelegationFeeRate,
		feeResetTimestamp = feeResetTimestamp,
	}
end

--- @param gatewayAddress WalletAddress
--- @param cursor string|nil a cursorId to paginate the vaults
--- @param limit number
--- @param sortBy "vaultId"|"startTimestamp"|"endTimestamp"|"balance"|"cursorId"|nil
--- @param sortOrder "asc"|"desc"|nil
--- @return PaginatedTable # A table containing the paginated vaults and pagination metadata
function gar.getPaginatedVaultsForGateway(gatewayAddress, cursor, limit, sortBy, sortOrder)
	local unsafeGateway = gar.getGatewayUnsafe(gatewayAddress)
	assert(unsafeGateway, "Gateway not found")

	local vaults = utils.reduce(unsafeGateway.vaults, function(acc, vaultId, vault)
		table.insert(acc, {
			vaultId = vaultId,
			cursorId = vaultId .. "_" .. vault.startTimestamp,
			balance = vault.balance,
			startTimestamp = vault.startTimestamp,
			endTimestamp = vault.endTimestamp,
		})
		return acc
	end, {})

	return utils.paginateTableWithCursor(
		vaults,
		cursor,
		"cursorId",
		limit,
		sortBy or "startTimestamp",
		sortOrder or "asc"
	)
end

--- @param gateway Gateway
--- @param vaultId WalletAddress | MessageId
--- @param qty mARIO
--- @param currentTimestamp Timestamp
function createGatewayWithdrawVault(gateway, vaultId, qty, currentTimestamp)
	assert(not gateway.vaults[vaultId], "Vault already exists")

	gateway.vaults[vaultId] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + gar.getSettings().operators.withdrawLengthMs,
	}
end

--- @param gateway Gateway
--- @param qty mARIO
--- @param currentTimestamp Timestamp
--- @param gatewayAddress WalletAddress
function createGatewayExitVault(gateway, qty, currentTimestamp, gatewayAddress)
	assert(not gateway.vaults[gatewayAddress], "Exit Vault already exists")
	gateway.vaults[gatewayAddress] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + gar.getSettings().operators.leaveLengthMs,
	}
end

--- @param gateway Gateway
--- @param delegateAddress WalletAddress
--- @param vaultId  MessageId
--- @param qty mARIO
--- @param currentTimestamp Timestamp
function createDelegateWithdrawVault(gateway, delegateAddress, vaultId, qty, currentTimestamp)
	local delegate = gateway.delegates[delegateAddress]
	assert(delegate, "Delegate not found")
	assert(not delegate.vaults[vaultId], "Vault already exists")

	-- Lock the qty in a vault to be unlocked after withdrawal period and decrease the gateway's total delegated stake
	gateway.delegates[delegateAddress].vaults[vaultId] = gar.createDelegateVault(qty, currentTimestamp)
end

---@param gateway Gateway
---@param vaultId MessageId
function cancelGatewayWithdrawVault(gateway, vaultId)
	local vault = gateway.vaults[vaultId]
	assert(vault, "Vault not found")
	gateway.vaults[vaultId] = nil
	gateway.operatorStake = gateway.operatorStake + vault.balance
end

---@param gateway Gateway
---@param gatewayAddress WalletAddress
---@param vaultId MessageId
function unlockGatewayWithdrawVault(gateway, gatewayAddress, vaultId)
	local vault = gateway.vaults[vaultId]
	assert(vault, "Vault not found")
	balances.increaseBalance(gatewayAddress, vault.balance)
	gateway.vaults[vaultId] = nil
end

---@param gateway Gateway
---@param delegateAddress WalletAddress
function cancelGatewayDelegateVault(gateway, delegateAddress, vaultId)
	local delegate = gateway.delegates[delegateAddress]
	assert(delegate, "Delegate not found")
	local vault = delegate.vaults[vaultId]
	assert(vault, "Vault not found")
	assert(gar.delegateAllowedToStake(delegateAddress, gateway), "This Gateway does not allow this delegate to stake.")

	gateway.delegates[delegateAddress].vaults[vaultId] = nil
	increaseDelegateStakeAtGateway(delegate, gateway, vault.balance)
end

---@param gateway Gateway
---@param delegateAddress WalletAddress
function unlockGatewayDelegateVault(gateway, delegateAddress, vaultId)
	local delegate = gateway.delegates[delegateAddress]
	assert(delegate, "Delegate not found")
	local vault = delegate.vaults[vaultId]
	assert(vault, "Vault not found")

	balances.increaseBalance(delegateAddress, vault.balance)
	-- delete the delegate's vault and prune the delegate if necessary
	gateway.delegates[delegateAddress].vaults[vaultId] = nil
	gar.pruneDelegateFromGatewayIfNecessary(delegateAddress, gateway)
end

--- @param gateway Gateway
--- @param qty mARIO
--- @param vaultId MessageId
function reduceStakeFromGatewayVault(gateway, qty, vaultId)
	local vault = gateway.vaults[vaultId]
	assert(vault, "Vault not found")
	assert(qty <= vault.balance, "Insufficient balance in vault")

	if qty == vault.balance then
		gateway.vaults[vaultId] = nil
	else
		gateway.vaults[vaultId].balance = vault.balance - qty
	end
end

--- @param gateway Gateway
--- @param delegateAddress WalletAddress
--- @param vaultId MessageId
function reduceStakeFromDelegateVault(gateway, delegateAddress, qty, vaultId)
	local delegate = gateway.delegates[delegateAddress]
	assert(delegate, "Delegate not found")
	local vault = delegate.vaults[vaultId]
	assert(vault, "Vault not found")
	assert(qty <= vault.balance, "Insufficient balance in vault")

	if qty == vault.balance then
		gateway.delegates[delegateAddress].vaults[vaultId] = nil
		gar.pruneDelegateFromGatewayIfNecessary(delegateAddress, gateway)
	else
		gateway.delegates[delegateAddress].vaults[vaultId].balance = vault.balance - qty
	end
end

--- @param timestamp Timestamp
function gar.scheduleNextGatewaysPruning(timestamp)
	NextGatewaysPruneTimestamp = math.min(NextGatewaysPruneTimestamp or timestamp, timestamp)
end

--- @param timestamp Timestamp
function gar.scheduleNextRedelegationsPruning(timestamp)
	NextRedelegationsPruneTimestamp = math.min(NextRedelegationsPruneTimestamp or timestamp, timestamp)
end

function gar.nextGatewaysPruneTimestamp()
	return NextGatewaysPruneTimestamp
end

function gar.nextRedelegationsPruneTimestamp()
	return NextRedelegationsPruneTimestamp
end

--- @class DelegatesFromAllGateways
--- @field cursorId string -- delegateAddress_gatewayAddress
--- @field address WalletAddress
--- @field gatewayAddress WalletAddress
--- @field startTimestamp Timestamp
--- @field delegatedStake mARIO
--- @field vaultedStake mARIO

--- @param cursor string|nil -- cursorId of the last item in the previous page
--- @param limit number
--- @param sortBy string|nil
--- @param sortOrder string|nil
--- @return PaginatedTable<DelegatesFromAllGateways>
function gar.getPaginatedDelegatesFromAllGateways(cursor, limit, sortBy, sortOrder)
	--- @type DelegatesFromAllGateways[]
	local allDelegations = {}

	for gatewayAddress, gateway in pairs(gar.getGatewaysUnsafe()) do
		for delegateAddress, delegate in pairs(gateway.delegates) do
			table.insert(allDelegations, {
				cursorId = delegateAddress .. "_" .. gatewayAddress,
				address = delegateAddress,
				gatewayAddress = gatewayAddress,
				startTimestamp = delegate.startTimestamp,
				delegatedStake = delegate.delegatedStake,
				vaultedStake = utils.reduce(delegate.vaults, function(acc, _, vault)
					return acc + vault.balance
				end, 0),
			})
		end
	end

	return utils.paginateTableWithCursor(
		allDelegations,
		cursor,
		"cursorId",
		limit,
		sortBy or "delegatedStake",
		sortOrder or "desc"
	)
end

--- @class VaultsFromAllGateways
--- @field cursorId string -- gatewayAddress_vaultId
--- @field vaultId MessageId
--- @field gatewayAddress WalletAddress
--- @field balance mARIO
--- @field startTimestamp Timestamp
--- @field endTimestamp Timestamp

--- @param cursor string|nil -- cursorId of the last item in the previous page
--- @param limit number
--- @param sortBy 'cursorId'|'vaultId'|'gatewayAddress'|'balance'|'startTimestamp'|'endTimestamp'|nil
--- @param sortOrder string|nil
--- @return PaginatedTable<VaultsFromAllGateways>
function gar.getPaginatedVaultsFromAllGateways(cursor, limit, sortBy, sortOrder)
	--- @type VaultsFromAllGateways[]
	local allVaults = {}

	local gateways = gar.getGatewaysUnsafe()
	for gatewayAddress, gateway in pairs(gateways) do
		for vaultId, vault in pairs(gateway.vaults) do
			table.insert(allVaults, {
				cursorId = gatewayAddress .. "_" .. vaultId,
				vaultId = vaultId,
				gatewayAddress = gatewayAddress,
				balance = vault.balance,
				startTimestamp = vault.startTimestamp,
				endTimestamp = vault.endTimestamp,
			})
		end
	end

	return utils.paginateTableWithCursor(
		allVaults,
		cursor,
		"cursorId",
		limit,
		sortBy or "startTimestamp",
		sortOrder or "asc"
	)
end

return gar
