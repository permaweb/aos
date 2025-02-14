local gar = require(".src.gar")
local crypto = require(".crypto.init")
local utils = require(".src.utils")
local balances = require(".src.balances")
local arns = require(".src.arns")
local epochs = {}

--- @alias ObserverAddress string
--- @alias DelegateAddress string
--- @alias TransactionId string

--- @class PrescribedEpoch
--- @field hashchain string The hashchain of the epoch
--- @field epochIndex number The index of the epoch
--- @field startTimestamp number The start timestamp of the epoch
--- @field endTimestamp number The end timestamp of the epoch
--- @field startHeight number The start height of the epoch
--- @field arnsStats ArNSStats The ArNS stats for the epoch
--- @field prescribedObservers table<ObserverAddress, GatewayAddress> The prescribed observers of the epoch
--- @field prescribedNames string[] The prescribed names of the epoch
--- @field distributions PrescribedEpochDistribution The distributions of the epoch
--- @field observations Observations The observations of the epoch

--- @class ArNSStats # The ArNS stats for an epoch
--- @field totalActiveNames number The total active ArNS names
--- @field totalGracePeriodNames number The total grace period ArNS names
--- @field totalReservedNames number The total reserved ArNS names
--- @field totalReturnedNames number The total returned ArNS names

--- @class DistributedEpoch : PrescribedEpoch
--- @field distributions DistributedEpochDistribution The rewards of the epoch

--- @class EpochSettings
--- @field prescribedNameCount number The number of prescribed names
--- @field rewardPercentage number The reward percentage
--- @field maxObservers number The maximum number of observers
--- @field epochZeroStartTimestamp number The start timestamp of epoch zero
--- @field durationMs number The duration of an epoch in milliseconds

--- @class WeightedGateway
--- @field gatewayAddress string The gateway address
--- @field observerAddress string The observer address
--- @field stakeWeight number The stake weight
--- @field tenureWeight number The tenure weight
--- @field gatewayPerformanceRatio number The gateway reward ratio weight
--- @field observerPerformanceRatio number The observer reward ratio weight
--- @field compositeWeight number The composite weight
--- @field normalizedCompositeWeight number The normalized composite weight

--- @class Observations
--- @field failureSummaries table The failure summaries
--- @field reports Reports The reports for the epoch (indexed by observer address)

--- @alias Reports table<ObserverAddress, string>

--- @class GatewayRewards
--- @field operatorReward number The total operator reward eligible
--- @field delegateRewards table<DelegateAddress, number> The delegate rewards eligible, indexed by delegate address

--- @class PrescribedEpochRewards
--- @field eligible table<GatewayAddress, GatewayRewards> The eligible rewards

--- @class DistributedEpochRewards: PrescribedEpochRewards
--- @field distributed table<GatewayAddress | DelegateAddress, number> The distributed rewards

--- @class PrescribedEpochDistribution
--- @field totalEligibleGateways number The total eligible gateways
--- @field totalEligibleRewards number The total eligible rewards
--- @field totalEligibleGatewayReward number The total eligible gateway reward
--- @field totalEligibleObserverReward number The total eligible observer reward
--- @field rewards PrescribedEpochRewards The rewards for the epoch, including eligible and distributed rewards

--- @class DistributedEpochDistribution: PrescribedEpochDistribution
--- @field distributedTimestamp number The distributed timestamp
--- @field totalDistributedRewards number The total distributed rewards
--- @field rewards DistributedEpochRewards The rewards for the epoch, including eligible and distributed rewards

--- Gets an epoch by index
--- @param epochIndex number The epoch index
--- @return  PrescribedEpoch | nil # The prescribed epoch
function epochs.getEpoch(epochIndex)
	if epochIndex < 0 then
		return nil
	end
	local epoch = utils.deepCopy(Epochs[epochIndex]) or nil
	return epoch
end

-- Gets an epoch by index, unsafe
--- @param epochIndex number The epoch index
--- @return PrescribedEpoch | nil # The prescribed epoch
function epochs.getEpochUnsafe(epochIndex)
	return Epochs[epochIndex]
end

--- Gets the epoch settings
--- @return EpochSettings # The epoch settings
function epochs.getSettings()
	return utils.deepCopy(EpochSettings)
end

--- Gets the raw prescribed observers for an epoch
--- @param epochIndex number The epoch index
--- @return table<WalletAddress, WalletAddress> # The prescribed observers for the epoch
function epochs.getPrescribedObserversForEpoch(epochIndex)
	if epochIndex < 0 then
		return {}
	end
	local epoch = epochs.getEpoch(epochIndex)
	return epoch and epoch.prescribedObservers or {}
end

--- Get prescribed observers with weights for epoch
--- @param epochIndex number The epoch index
--- @return WeightedGateway[] # The prescribed observers with weights for the epoch
function epochs.getPrescribedObserversWithWeightsForEpoch(epochIndex)
	local prescribedObservers = epochs.getPrescribedObserversForEpoch(epochIndex)
	-- Iterate over prescribed observers and add gateway details
	local prescribedObserversWithWeights = {}
	for _, gatewayAddress in pairs(prescribedObservers) do
		local gateway = gar.getGatewayUnsafe(gatewayAddress)
		if gateway then
			table.insert(prescribedObserversWithWeights, {
				observerAddress = gateway.observerAddress,
				gatewayAddress = gatewayAddress,
				normalizedCompositeWeight = gateway.weights.normalizedCompositeWeight,
				stakeWeight = gateway.weights.stakeWeight,
				tenureWeight = gateway.weights.tenureWeight,
				gatewayPerformanceRatio = gateway.weights.gatewayPerformanceRatio,
				observerPerformanceRatio = gateway.weights.observerPerformanceRatio,
				compositeWeight = gateway.weights.compositeWeight,
				stake = gateway.operatorStake,
				startTimestamp = gateway.startTimestamp,
			})
		end
	end

	-- sort by normalizedCompositeWeight
	table.sort(prescribedObserversWithWeights, function(a, b)
		return a.normalizedCompositeWeight > b.normalizedCompositeWeight
	end)
	return prescribedObserversWithWeights
end

--- Gets the eligible rewards for an epoch
--- @param epochIndex number The epoch index
--- @return PrescribedEpochRewards # The eligible rewards for the epoch
function epochs.getEligibleRewardsForEpoch(epochIndex)
	local epoch = epochs.getEpoch(epochIndex)
	local eligible = epoch
			and epoch.distributions
			and epoch.distributions.rewards
			and epoch.distributions.rewards.eligible
		or {}
	return eligible
end

--- Gets the observations for an epoch
--- @param epochIndex number The epoch index
--- @return Observations # The observations for the epoch
function epochs.getObservationsForEpoch(epochIndex)
	if epochIndex < 0 then
		return {}
	end
	local epoch = epochs.getEpoch(epochIndex)
	return epoch and epoch.observations or {}
end

--- Gets the distributions for an epoch
--- @param epochIndex number The epoch index
--- @return PrescribedEpochDistribution # The distributions for the epoch
function epochs.getDistributionsForEpoch(epochIndex)
	if epochIndex < 0 then
		return {}
	end
	local epoch = epochs.getEpoch(epochIndex)
	return epoch and epoch.distributions or {}
end

--- @class EligibleRewardTotals
--- @field totalEligibleGateways number The total eligible gateways
--- @field totalEligibleRewards number The total eligible rewards
--- @field totalEligibleGatewayReward number The total eligible gateway reward
--- @field totalEligibleObserverReward number The total eligible observer reward

-- TODO: Replace getDistributionsForEpoch function with this once network portal uses paginated handler
--- @param epochIndex number The epoch index
--- @return EligibleRewardTotals | nil # The totals for the eligible rewards for the epoch
function epochs.getTotalEligibleRewardsForEpoch(epochIndex)
	local epoch = epochs.getEpochUnsafe(epochIndex)
	if not epoch or not epoch.distributions then
		return nil
	end

	return {
		totalEligibleGateways = epoch.distributions.totalEligibleGateways,
		totalEligibleRewards = epoch.distributions.totalEligibleRewards,
		totalEligibleGatewayReward = epoch.distributions.totalEligibleGatewayReward,
		totalEligibleObserverReward = epoch.distributions.totalEligibleObserverReward,
	}
end

--- Gets the prescribed names for an epoch
--- @param epochIndex number The epoch index
--- @return string[] # The prescribed names for the epoch
function epochs.getPrescribedNamesForEpoch(epochIndex)
	if epochIndex < 0 then
		return {}
	end
	local epoch = epochs.getEpoch(epochIndex)
	return epoch and epoch.prescribedNames or {}
end

--- Gets the reports for an epoch
--- @param epochIndex number The epoch index
--- @return table<WalletAddress, TransactionId> # The reports for the epoch
function epochs.getReportsForEpoch(epochIndex)
	if epochIndex < 0 then
		return {}
	end
	local epoch = epochs.getEpoch(epochIndex)
	return epoch and epoch.observations.reports or {}
end

--- Computes the prescribed names for an epoch
--- @param epochIndex number The epoch index
--- @param hashchain string The hashchain
--- @return string[] # The prescribed names for the epoch
function epochs.computePrescribedNamesForEpoch(epochIndex, hashchain)
	if epochIndex < 0 then
		return {}
	end
	local epochStartTimestamp, epochEndTimestamp = epochs.getEpochTimestampsForIndex(epochIndex)
	local activeArNSNames = arns.getActiveArNSNamesBetweenTimestamps(epochStartTimestamp, epochEndTimestamp)

	-- sort active records by name and hashchain
	table.sort(activeArNSNames, function(nameA, nameB)
		local nameAHash = utils.getHashFromBase64URL(nameA)
		local nameBHash = utils.getHashFromBase64URL(nameB)
		local nameAString = crypto.utils.array.toString(nameAHash)
		local nameBString = crypto.utils.array.toString(nameBHash)
		return nameAString < nameBString
	end)

	if #activeArNSNames <= epochs.getSettings().prescribedNameCount then
		return activeArNSNames
	end

	local epochHash = utils.getHashFromBase64URL(hashchain)
	local prescribedNamesLookup = {}
	local hash = epochHash
	while utils.lengthOfTable(prescribedNamesLookup) < epochs.getSettings().prescribedNameCount do
		local hashString = crypto.utils.array.toString(hash)
		local random = crypto.random(nil, nil, hashString) % #activeArNSNames

		for i = 0, #activeArNSNames do
			local index = (random + i) % #activeArNSNames + 1
			local alreadyPrescribed = prescribedNamesLookup[activeArNSNames[index]] ~= nil
			if not alreadyPrescribed then
				prescribedNamesLookup[activeArNSNames[index]] = true
				break
			end
		end

		-- hash the hash to get a new hash
		local newHash = crypto.utils.stream.fromArray(hash)
		hash = crypto.digest.sha2_256(newHash).asBytes()
	end

	local prescribedNames = utils.getTableKeys(prescribedNamesLookup)

	-- sort them by name
	table.sort(prescribedNames, function(a, b)
		return a < b
	end)
	return prescribedNames
end

--- Computes the prescribed observers for an epoch
--- @param epochIndex number The epoch index
--- @param hashchain string The hashchain
--- @return table<WalletAddress, WalletAddress>, WeightedGateway[] # The prescribed observers for the epoch, and all the gateways with weights
function epochs.computePrescribedObserversForEpoch(epochIndex, hashchain)
	assert(epochIndex >= 0, "Epoch index must be greater than or equal to 0")
	assert(type(hashchain) == "string", "Hashchain must be a string")

	local epochStartTimestamp = epochs.getEpochTimestampsForIndex(epochIndex)
	local activeGatewayAddresses = gar.getActiveGatewayAddressesBeforeTimestamp(epochStartTimestamp)
	local weightedGateways = gar.getGatewayWeightsAtTimestamp(activeGatewayAddresses, epochStartTimestamp)

	-- Filter out any observers that could have a normalized composite weight of 0
	local filteredObservers = {}
	local prescribedObserversLookup = {}
	-- use ipairs as weightedObservers in array
	for _, observer in ipairs(weightedGateways) do
		if observer.normalizedCompositeWeight > 0 then
			table.insert(filteredObservers, observer)
		end
	end
	if #filteredObservers <= epochs.getSettings().maxObservers then
		for _, observer in ipairs(filteredObservers) do
			prescribedObserversLookup[observer.observerAddress] = observer.gatewayAddress
		end
		return prescribedObserversLookup, weightedGateways
	end

	-- the hash we will use to create entropy for prescribed observers
	local epochHash = utils.getHashFromBase64URL(hashchain)

	-- sort the observers using entropy from the hash chain, this will ensure that the same observers are selected for the same epoch
	table.sort(filteredObservers, function(observerA, observerB)
		local addressAHash = utils.getHashFromBase64URL(observerA.gatewayAddress .. hashchain)
		local addressBHash = utils.getHashFromBase64URL(observerB.gatewayAddress .. hashchain)
		local addressAString = crypto.utils.array.toString(addressAHash)
		local addressBString = crypto.utils.array.toString(addressBHash)
		return addressAString < addressBString
	end)

	-- get our prescribed observers, using the hashchain as entropy
	local hash = epochHash
	while utils.lengthOfTable(prescribedObserversLookup) < epochs.getSettings().maxObservers do
		local hashString = crypto.utils.array.toString(hash)
		local random = crypto.random(nil, nil, hashString) / 0xffffffff
		local cumulativeNormalizedCompositeWeight = 0
		for _, observer in ipairs(filteredObservers) do
			local alreadyPrescribed = prescribedObserversLookup[observer.observerAddress]
			-- add only if observer has not already been prescribed
			if not alreadyPrescribed then
				-- add the observers normalized composite weight to the cumulative weight
				cumulativeNormalizedCompositeWeight = cumulativeNormalizedCompositeWeight
					+ observer.normalizedCompositeWeight
				-- if the random value is less than the cumulative weight, we have found our observer
				if random <= cumulativeNormalizedCompositeWeight then
					prescribedObserversLookup[observer.observerAddress] = observer.gatewayAddress
					break
				end
			end
		end
		-- hash the hash to get a new hash
		local newHash = crypto.utils.stream.fromArray(hash)
		hash = crypto.digest.sha2_256(newHash).asBytes()
	end
	-- return the prescribed observers and the weighted observers
	return prescribedObserversLookup, weightedGateways
end

--- Gets the epoch timestamps for an epoch index. Epochs are 0-indexed.
--- @param epochIndex number The epoch index
--- @return number, number # 	The epoch start timestamp, epoch end timestamp
function epochs.getEpochTimestampsForIndex(epochIndex)
	if epochIndex < 0 then
		return 0, 0
	end
	local epochStartTimestamp = epochs.getSettings().epochZeroStartTimestamp
		+ epochs.getSettings().durationMs * epochIndex
	local epochEndTimestamp = epochStartTimestamp + epochs.getSettings().durationMs
	return epochStartTimestamp, epochEndTimestamp
end

--- Gets the epoch index for a given timestamp. Epochs are 0-indexed.
--- @param timestamp number The timestamp
--- @return number # 	The epoch index
function epochs.getEpochIndexForTimestamp(timestamp)
	local timestampInMS = utils.checkAndConvertTimestampToMs(timestamp)
	local epochZeroStartTimestamp = epochs.getSettings().epochZeroStartTimestamp
	local epochLengthMs = epochs.getSettings().durationMs
	local epochIndex = math.floor((timestampInMS - epochZeroStartTimestamp) / epochLengthMs)
	return epochIndex
end

--- Creates a new epoch and updates the gateway weights
---
--- TODO: if we are asked to create an epoch to catch up, we should stub out the prescribed observers and names. Non-critical.
--- @param currentTimestamp number The current timestamp in milliseconds
--- @param currentBlockHeight number The current block height
--- @param currentHashchain string The current hashchain
--- @return PrescribedEpoch | nil # The created epoch, or nil if an epoch already exists for the index
function epochs.createAndPrescribeNewEpoch(currentTimestamp, currentBlockHeight, currentHashchain)
	assert(type(currentTimestamp) == "number", "Timestamp must be a number")
	assert(type(currentBlockHeight) == "number", "Block height must be a number")
	assert(type(currentHashchain) == "string", "Hashchain must be a string")

	-- if before the epoch zero start timestamp, return nil
	if currentTimestamp < epochs.getSettings().epochZeroStartTimestamp then
		print("Genesis epoch will start at: " .. epochs.getSettings().epochZeroStartTimestamp)
		return nil
	end

	local currentEpochIndex = epochs.getEpochIndexForTimestamp(currentTimestamp)
	if epochs.getEpoch(currentEpochIndex) then
		print("Epoch already exists for index, skipping creation: " .. currentEpochIndex)
		return nil -- do not return the existing epoch to prevent sending redundant epoch-created-notices
	end

	print("Creating new epoch: " .. currentEpochIndex)

	-- get the max rewards for each participant eligible for the epoch
	local prescribedObservers, updatedGatewaysWithWeights =
		epochs.computePrescribedObserversForEpoch(currentEpochIndex, currentHashchain)
	local prescribedNames = epochs.computePrescribedNamesForEpoch(currentEpochIndex, currentHashchain)
	local eligibleEpochRewards = epochs.computeTotalEligibleRewardsForEpoch(currentEpochIndex, prescribedObservers)
	local epochStartTimestamp, epochEndTimestamp = epochs.getEpochTimestampsForIndex(currentEpochIndex)
	local arnsStatsAtEpochStart = arns.getArNSStatsAtTimestamp(epochStartTimestamp)

	-- always update the gateway weights to the latest computed weights when we create a new epoch
	for _, weightedGateway in ipairs(updatedGatewaysWithWeights) do
		gar.updateGatewayWeights(weightedGateway)
	end

	--- @type PrescribedEpoch
	local epoch = {
		hashchain = currentHashchain,
		epochIndex = currentEpochIndex,
		startTimestamp = epochStartTimestamp,
		endTimestamp = epochEndTimestamp,
		startHeight = currentBlockHeight,
		arnsStats = arnsStatsAtEpochStart,
		prescribedObservers = prescribedObservers,
		prescribedNames = prescribedNames,
		observations = {
			failureSummaries = {},
			reports = {},
		},
		distributions = {
			totalEligibleRewards = eligibleEpochRewards.totalEligibleRewards,
			totalEligibleGatewayReward = eligibleEpochRewards.perGatewayReward,
			totalEligibleObserverReward = eligibleEpochRewards.perObserverReward,
			totalEligibleGateways = eligibleEpochRewards.totalEligibleGateways,
			rewards = {
				eligible = eligibleEpochRewards.potentialRewards,
			},
		},
	}
	Epochs[currentEpochIndex] = epoch

	return epoch
end

--- Saves the observations for an epoch
--- @param observerAddress string The observer address
--- @param reportTxId string The report transaction ID
--- @param failedGatewayAddresses table<GatewayAddress> The failed gateway addresses
--- @param epochIndex number The epoch index
--- @param currentTimestamp number The current timestamp
--- @return Observations # The updated observations for the epoch
function epochs.saveObservations(observerAddress, reportTxId, failedGatewayAddresses, epochIndex, currentTimestamp)
	-- Note: one of the only places we use arweave addresses, as the protocol requires the report to be stored on arweave. This would be a significant change to OIP if changed.
	assert(utils.isValidArweaveAddress(reportTxId), "Report transaction ID is not a valid address")
	assert(utils.isValidAddress(observerAddress, true), "Observer address is not a valid address") -- allow unsafe addresses for observer address
	assert(type(failedGatewayAddresses) == "table", "Failed gateway addresses is required")
	for _, address in ipairs(failedGatewayAddresses) do
		assert(utils.isValidAddress(address, true), "Failed gateway address is not a valid address") -- allow unsafe addresses for failed gateway addresses
	end
	assert(epochIndex >= 0, "Epoch index must be greater than 0")
	assert(type(currentTimestamp) == "number", "Timestamp is required")

	local epochStartTimestamp, epochEndTimestamp = epochs.getEpochTimestampsForIndex(epochIndex)

	-- avoid observations before the previous epoch distribution has occurred, as distributions affect weights of the current epoch
	assert(
		currentTimestamp > epochStartTimestamp,
		"Observations for epoch " .. epochIndex .. " must be submitted after " .. epochStartTimestamp
	)
	assert(
		currentTimestamp < epochEndTimestamp,
		"Observations for epoch " .. epochIndex .. " must be submitted before " .. epochEndTimestamp
	)

	local prescribedObserversLookup = epochs.getPrescribedObserversForEpoch(epochIndex)
	assert(utils.lengthOfTable(prescribedObserversLookup) > 0, "No prescribed observers for the current epoch.")

	local gatewayAddressForObserver = prescribedObserversLookup[observerAddress]
	assert(gatewayAddressForObserver, "Caller is not a prescribed observer for the current epoch.")

	local observingGateway = gar.getGateway(gatewayAddressForObserver)
	assert(observingGateway, "The associated gateway not found in the registry.")

	-- we'll be updating the epoch, so get a direct reference to it
	local epoch = epochs.getEpochUnsafe(epochIndex)
	assert(epoch, "Unable to save observation. Epoch not found for index: " .. epochIndex)

	-- check if this is the first report filed in this epoch
	if epoch.observations == nil then
		epoch.observations = {
			failureSummaries = {},
			reports = {},
		}
	end

	-- use ipairs as failedGatewayAddresses is an array
	for _, failedGatewayAddress in ipairs(failedGatewayAddresses) do
		-- we're not updating the gateway, so we can use getGatewayUnsafe without fear of overwriting the gateway
		local gateway = gar.getGatewayUnsafe(failedGatewayAddress)

		if gateway then
			local gatewayPresentDuringEpoch = gar.isGatewayActiveBeforeTimestamp(epochStartTimestamp, gateway)
			if gatewayPresentDuringEpoch then
				-- if there are none, create an array
				if epoch.observations.failureSummaries == nil then
					epoch.observations.failureSummaries = {}
				end
				-- Get the existing set of failed gateways for this observer
				local observersMarkedFailed = epoch.observations.failureSummaries[failedGatewayAddress] or {}

				-- if list of observers who marked failed does not continue current observer than add it
				local alreadyObservedIndex = utils.findInArray(observersMarkedFailed, function(address)
					return address == observingGateway.observerAddress
				end)

				if not alreadyObservedIndex then
					table.insert(observersMarkedFailed, observingGateway.observerAddress)
				end

				epoch.observations.failureSummaries[failedGatewayAddress] = observersMarkedFailed
			end
		end
	end

	-- if reports are not already present, create an array
	if epoch.observations.reports == nil then
		epoch.observations.reports = {}
	end

	-- update the epoch
	epoch.observations.reports[observingGateway.observerAddress] = reportTxId
	return epoch.observations
end

--- @class DistributionSettings
--- @field gatewayOperatorRewardRate number The gateway operator reward ratio
--- @field observerRewardRate number The observer reward ratio
--- @field rewardDecayStartEpoch number The reward decay start epoch
--- @field rewardDecayLastEpoch number The reward decay last epoch
--- @field maximumRewardRate number The maximum reward rate
--- @field minimumRewardRate number The minimum reward rate
function epochs.getDistributionSettings()
	return utils.deepCopy(DistributionSettings)
end

--- @class ComputedRewards
--- @field totalEligibleGateways number The total eligible gateways
--- @field totalEligibleRewards number The total eligible rewards
--- @field perGatewayReward number The per gateway reward
--- @field perObserverReward number The per observer reward
--- @field potentialRewards table<string, GatewayRewards> The potential rewards for each gateway

--- Computes the total eligible rewards for an epoch based on the protocol balance and the reward percentage and prescribed observers
--- @param epochIndex number The epoch index
--- @param prescribedObserversLookup table<WalletAddress, WalletAddress> The prescribed observers for the epoch
--- @return ComputedRewards # The total eligible rewards
function epochs.computeTotalEligibleRewardsForEpoch(epochIndex, prescribedObserversLookup)
	if epochIndex < 0 then
		return {
			totalEligibleGateways = 0,
			totalEligibleRewards = 0,
			perGatewayReward = 0,
			perObserverReward = 0,
			potentialRewards = {},
		}
	end
	local distributionSettings = epochs.getDistributionSettings()
	local epochStartTimestamp = epochs.getEpochTimestampsForIndex(epochIndex)
	local activeGatewayAddresses = gar.getActiveGatewayAddressesBeforeTimestamp(epochStartTimestamp)
	local protocolBalance = balances.getBalance(ao.id)
	local rewardRate = epochs.getRewardRateForEpoch(epochIndex)
	local totalEligibleRewards = math.floor(protocolBalance * rewardRate)
	local eligibleGatewayReward = #activeGatewayAddresses > 0
			and math.floor(
				totalEligibleRewards * distributionSettings.gatewayOperatorRewardRate / #activeGatewayAddresses
			)
		or 0
	local eligibleObserverReward = utils.lengthOfTable(prescribedObserversLookup) > 0
			and math.floor(
				totalEligibleRewards
					* distributionSettings.observerRewardRate
					/ utils.lengthOfTable(prescribedObserversLookup)
			)
		or 0
	-- compute for each gateway what their potential rewards are and for their delegates
	local potentialRewards = {}
	-- use ipairs as activeGatewayAddresses is an array
	for _, gatewayAddress in ipairs(activeGatewayAddresses) do
		local gateway = gar.getGateway(gatewayAddress)
		if gateway ~= nil then
			local potentialReward = eligibleGatewayReward -- start with the gateway reward
			-- it it is a prescribed observer for the epoch, it is eligible for the observer reward
			if prescribedObserversLookup[gateway.observerAddress] then
				potentialReward = potentialReward + eligibleObserverReward -- add observer reward if it is a prescribed observer
			end
			-- if any delegates are present, distribute the rewards to the delegates
			local eligibleDelegateRewards = gateway.totalDelegatedStake > 0
					and math.floor(potentialReward * (gateway.settings.delegateRewardShareRatio / 100))
				or 0
			-- set the potential reward for the gateway
			local eligibleOperatorRewards = potentialReward - eligibleDelegateRewards
			local eligibleRewardsForGateway = {
				operatorReward = eligibleOperatorRewards,
				delegateRewards = {},
			}
			-- use pairs as gateway.delegates is map
			for delegateAddress, delegate in pairs(gateway.delegates) do
				if gateway.totalDelegatedStake > 0 then
					local delegateReward =
						math.floor((delegate.delegatedStake / gateway.totalDelegatedStake) * eligibleDelegateRewards)
					if delegateReward > 0 then
						eligibleRewardsForGateway.delegateRewards[delegateAddress] = delegateReward
					end
				end
			end
			-- set the potential rewards for the gateway
			potentialRewards[gatewayAddress] = eligibleRewardsForGateway
		end
	end
	return {
		totalEligibleGateways = #activeGatewayAddresses,
		totalEligibleRewards = totalEligibleRewards,
		perGatewayReward = eligibleGatewayReward,
		perObserverReward = eligibleObserverReward,
		potentialRewards = potentialRewards,
	}
end
--- Distributes the rewards for a prescribed epoch
--- 1. Calculate the rewards for the epoch based on protocol balance
--- 2. Allocate 95% of the rewards for passed gateways, 5% for observers - based on total gateways during the epoch and # of prescribed observers
--- 3. Distribute the rewards to the gateways and observers
--- 4. Increment the epoch stats for the gateways
--- @param epochIndexToDistribute number The epoch to distribute
--- @param currentTimestamp number The current timestamp
--- @return DistributedEpoch | nil # The updated epoch with the distributed rewards, or nil if no rewards were distributed
function epochs.distributeEpoch(epochIndexToDistribute, currentTimestamp)
	if epochIndexToDistribute < 0 then
		-- silently ignore - Distribution can only occur after the epoch has ended
		return nil
	end

	-- get the epoch reference to avoid extra copying, it will be set to nil after the distribution is complete
	local epochToDistribute = epochs.getEpoch(epochIndexToDistribute)

	if not epochToDistribute then
		-- TODO: consider throwing an error here instead of silently returning, as this is a critical error and should be fixed
		print("Epoch " .. epochIndexToDistribute .. " not found in state. Skipping distribution.")
		return nil
	end

	--- The epoch was already distributed and should be cleaned up
	--- @cast epochToDistribute DistributedEpoch
	if epochToDistribute.distributions.distributedTimestamp then
		print(
			"Rewards already distributed for epoch. Epoch will be removed from the epoch registry: "
				.. epochIndexToDistribute
		)
		Epochs[epochIndexToDistribute] = nil
		return nil -- do not return the epoch as it has already been distributed, and we do not want to send redundant epoch-distributed-notices
	end

	-- ensure we are not distributing the current epoch, that can only happen
	if currentTimestamp < epochToDistribute.endTimestamp then
		print("Epoch will be distributed after the current timestamp: " .. epochToDistribute.endTimestamp)
		return nil
	end

	print("Distributing epoch: " .. epochIndexToDistribute)

	local eligibleGatewaysForEpoch = epochToDistribute.distributions.rewards.eligible or {}
	local prescribedObserversLookup = epochToDistribute.prescribedObservers or {}
	local totalEligibleObserverReward = epochToDistribute.distributions.totalEligibleObserverReward or 0
	local totalEligibleGatewayReward = epochToDistribute.distributions.totalEligibleGatewayReward or 0
	local totalObservationsSubmitted = utils.lengthOfTable(epochToDistribute.observations.reports) or 0
	local prescribedObserversWithWeights =
		epochs.getPrescribedObserversWithWeightsForEpoch(epochToDistribute.epochIndex)
	local epochToDistributeReports = epochToDistribute.observations and epochToDistribute.observations.reports or {}
	local epochToDistributeFailureSummaries = epochToDistribute.observations
			and epochToDistribute.observations.failureSummaries
		or {}
	local missedObservationPenaltyRate = epochs.getDistributionSettings().missedObservationPenaltyRate
	local distributed = {}
	for gatewayAddress, totalEligibleRewardsForGateway in pairs(eligibleGatewaysForEpoch) do
		local gateway = gar.getGateway(gatewayAddress)
		-- only distribute rewards if the gateway is found and not leaving
		if gateway and totalEligibleRewardsForGateway and gateway.status ~= "leaving" then
			-- check the observations to see if gateway passed, if 50% or more of the observers marked the gateway as failed, it is considered failed
			local observersMarkedFailed = epochToDistributeFailureSummaries[gatewayAddress] or {}
			local failed = #observersMarkedFailed > (totalObservationsSubmitted / 2) -- more than 50% of observations submitted marked gateway as failed

			-- if prescribed, we'll update the prescribed stats as well - find if the observer address is in prescribed observers
			local isPrescribed = prescribedObserversLookup[gateway.observerAddress]

			local observationSubmitted = isPrescribed and epochToDistributeReports[gateway.observerAddress] ~= nil

			local updatedStats = {
				totalEpochCount = gateway.stats.totalEpochCount + 1,
				failedEpochCount = failed and gateway.stats.failedEpochCount + 1 or gateway.stats.failedEpochCount,
				failedConsecutiveEpochs = failed and gateway.stats.failedConsecutiveEpochs + 1 or 0,
				passedConsecutiveEpochs = failed and 0 or gateway.stats.passedConsecutiveEpochs + 1,
				passedEpochCount = failed and gateway.stats.passedEpochCount or gateway.stats.passedEpochCount + 1,
				prescribedEpochCount = isPrescribed and gateway.stats.prescribedEpochCount + 1
					or gateway.stats.prescribedEpochCount,
				observedEpochCount = observationSubmitted and gateway.stats.observedEpochCount + 1
					or gateway.stats.observedEpochCount,
			}

			-- update the gateway stats, returns the updated gateway
			gateway = gar.updateGatewayStats(gatewayAddress, gateway, updatedStats)

			-- Scenarios
			-- 1. Gateway passed and was prescribed and submitted an observation - it gets full gateway reward
			-- 2. Gateway passed and was prescribed and did not submit an observation - it gets only the gateway reward, docked by 25%
			-- 2. Gateway passed and was not prescribed -- it gets full operator reward
			-- 3. Gateway failed and was prescribed and did not submit observation -- it gets no reward
			-- 3. Gateway failed and was prescribed and did submit observation -- it gets the observer reward
			-- 4. Gateway failed and was not prescribed -- it gets no reward
			local earnedRewardForGatewayAndDelegates = 0
			if not failed then
				if isPrescribed then
					if observationSubmitted then
						-- 1. gateway passed and was prescribed and submitted an observation - it gets full reward
						earnedRewardForGatewayAndDelegates =
							math.floor(totalEligibleGatewayReward + totalEligibleObserverReward)
					else
						-- 2. gateway passed and was prescribed and did not submit an observation - it gets only the gateway reward, docked by 25%
						earnedRewardForGatewayAndDelegates =
							math.floor(totalEligibleGatewayReward * (1 - missedObservationPenaltyRate))
					end
				else
					-- 3. gateway passed and was not prescribed -- it gets full gateway reward
					earnedRewardForGatewayAndDelegates = math.floor(totalEligibleGatewayReward)
				end
			else
				if isPrescribed then
					if observationSubmitted then
						-- 3. gateway failed and was prescribed and did submit an observation -- it gets the observer reward
						earnedRewardForGatewayAndDelegates = math.floor(totalEligibleObserverReward)
					end
				end
			end

			local totalEligibleRewardsForGatewayAndDelegates = totalEligibleRewardsForGateway.operatorReward
				+ utils.sumTableValues(totalEligibleRewardsForGateway.delegateRewards)

			if earnedRewardForGatewayAndDelegates > 0 and totalEligibleRewardsForGatewayAndDelegates > 0 then
				local percentOfEligibleEarned = earnedRewardForGatewayAndDelegates
					/ totalEligibleRewardsForGatewayAndDelegates -- percent of what was earned vs what was eligible
				-- optimally this is 1, but if the gateway did not do what it was supposed to do, it will be less than 1 and thus all payouts will be less
				local totalDistributedToDelegates = 0
				local totalRewardsForMissingDelegates = 0
				-- distribute all the predetermined rewards to the delegates
				for delegateAddress, eligibleDelegateReward in pairs(totalEligibleRewardsForGateway.delegateRewards) do
					local actualDelegateReward = math.floor(eligibleDelegateReward * percentOfEligibleEarned)
					-- distribute the rewards to the delegate if greater than 0 and the delegate still exists on the gateway and has a stake greater than 0
					if actualDelegateReward > 0 then
						if gar.isDelegateEligibleForDistributions(gateway, delegateAddress) then
							-- increase the stake and decrease the protocol balance, returns the updated gateway
							gateway = gar.increaseExistingDelegateStake(
								gatewayAddress,
								gateway,
								delegateAddress,
								actualDelegateReward
							)
							balances.reduceBalance(ao.id, actualDelegateReward)
							-- update the distributed rewards for the delegate
							distributed[delegateAddress] = (distributed[delegateAddress] or 0) + actualDelegateReward
							totalDistributedToDelegates = totalDistributedToDelegates + actualDelegateReward
						else
							totalRewardsForMissingDelegates = totalRewardsForMissingDelegates + actualDelegateReward
						end
					end
				end
				-- transfer the remaining rewards to the gateway
				local actualOperatorReward = math.floor(
					earnedRewardForGatewayAndDelegates - totalDistributedToDelegates - totalRewardsForMissingDelegates
				)
				if actualOperatorReward > 0 then
					-- distribute the rewards to the gateway and allow potentially unsafe addresses given they can join the network if they are transferred balance
					balances.transfer(gatewayAddress, ao.id, actualOperatorReward, true)
					-- move that balance to the gateway if auto-staking is on
					if gateway.settings.autoStake then
						-- only increase stake if the gateway is joined, otherwise it is leaving and cannot accept additional stake so distribute rewards to the operator directly
						gar.increaseOperatorStake(gatewayAddress, actualOperatorReward)
					end
				end
				-- update the distributed rewards for the gateway
				distributed[gatewayAddress] = (distributed[gatewayAddress] or 0) + actualOperatorReward
			end
		end
	end

	-- create a distributed epoch from the prescribed epoch
	local distributedEpoch = convertPrescribedEpochToDistributedEpoch(
		epochToDistribute,
		currentTimestamp,
		distributed,
		prescribedObserversWithWeights
	)
	-- remove the epoch from the epoch table
	Epochs[epochIndexToDistribute] = nil
	return distributedEpoch
end

--- Creates a distributed epoch from a prescribed epoch
--- @param epoch PrescribedEpoch # The prescribed epoch
--- @param currentTimestamp number # The current timestamp
--- @param distributed table<GatewayAddress | WalletAddress, number> # The distributed rewards for the epoch
--- @return DistributedEpoch # The distributed epoch
function convertPrescribedEpochToDistributedEpoch(epoch, currentTimestamp, distributed, prescribedObservers)
	return {
		hashchain = epoch.hashchain,
		epochIndex = epoch.epochIndex,
		startTimestamp = epoch.startTimestamp,
		endTimestamp = epoch.endTimestamp,
		startHeight = epoch.startHeight,
		prescribedObservers = prescribedObservers,
		prescribedNames = epoch.prescribedNames,
		observations = epoch.observations,
		distributions = {
			distributedTimestamp = currentTimestamp,
			totalDistributedRewards = utils.sumTableValues(distributed),
			totalEligibleGateways = epoch.distributions.totalEligibleGateways,
			totalEligibleRewards = epoch.distributions.totalEligibleRewards,
			totalEligibleGatewayReward = epoch.distributions.totalEligibleGatewayReward,
			totalEligibleObserverReward = epoch.distributions.totalEligibleObserverReward,
			rewards = {
				eligible = epoch.distributions.rewards.eligible or {},
				distributed = distributed or {},
			},
		},
		arnsStats = epoch.arnsStats,
	}
end

--- Gets the reward rate for an epoch. The reward rate is the percentage of the protocol balance that is distributed to the gateways and observers.
--- For the first year, the reward rate is 0.1% of the protocol balance.
--- After the first year, the reward rate decays linearly to 0.05% of the protocol balance after 1.5 years.
---@param epochIndex number
---@returns number
function epochs.getRewardRateForEpoch(epochIndex)
	local distributionSettings = epochs.getDistributionSettings()

	-- if we are before the decay start, return the maximum reward rate (0.1%)
	if epochIndex < distributionSettings.rewardDecayStartEpoch then
		return distributionSettings.maximumRewardRate
	end

	-- if at the end of the decay period, return the minimum reward rate (0.05%)
	if epochIndex > distributionSettings.rewardDecayLastEpoch then
		return distributionSettings.minimumRewardRate
	end
	-- if we are in the decay period (1 year to 1.5 years), return the linearly decaying reward rate
	local totalDecayPeriod = (distributionSettings.rewardDecayLastEpoch - distributionSettings.rewardDecayStartEpoch)
	local epochsAlreadyDecayed = (epochIndex - distributionSettings.rewardDecayStartEpoch)
	local decayRatePerEpoch = (distributionSettings.maximumRewardRate - distributionSettings.minimumRewardRate)
		/ totalDecayPeriod
	local totalRateDecayed = decayRatePerEpoch * epochsAlreadyDecayed
	local totalRewardRateDecayed = distributionSettings.maximumRewardRate - totalRateDecayed
	-- avoid floating point precision issues, round to 5 decimal places
	return utils.roundToPrecision(totalRewardRateDecayed, 5)
end

--- @class EligibleRewards
--- @field recipient WalletAddress
--- @field eligibleReward mARIO
--- @field gatewayAddress WalletAddress
--- @field type "delegateReward"|"operatorReward"
--- @field cursorId string gatewayAddress concatenated with recipient for pagination

--- Gets the distributions for the current epoch
--- @param currentTimestamp number
--- @param cursor string|nil The cursor to paginate from
--- @param limit number The limit of records to return
--- @param sortBy string|nil The field to sort by
--- @param sortOrder string The order to sort by
--- @return PaginatedTable<PrescribedEpochDistribution> The paginated eligible distributions for the epoch
function epochs.getEligibleDistributions(currentTimestamp, cursor, limit, sortBy, sortOrder)
	local epochIndex = epochs.getEpochIndexForTimestamp(currentTimestamp)
	if epochIndex < 0 then
		return {}
	end
	local epoch = epochs.getEpochUnsafe(epochIndex)
	if
		not epoch
		or not epoch.distributions
		or not epoch.distributions.rewards
		or not epoch.distributions.rewards.eligible
	then
		return {}
	end

	local rewardsArray = {}
	for gatewayAddress, reward in pairs(epoch.distributions.rewards.eligible) do
		table.insert(rewardsArray, {
			type = "operatorReward",
			recipient = gatewayAddress,
			eligibleReward = reward.operatorReward,
			gatewayAddress = gatewayAddress,
			cursorId = gatewayAddress .. "_" .. gatewayAddress,
		})

		for delegateAddress, delegateRewardQty in pairs(reward.delegateRewards) do
			table.insert(rewardsArray, {
				type = "delegateReward",
				recipient = delegateAddress,
				eligibleReward = delegateRewardQty,
				gatewayAddress = gatewayAddress,
				cursorId = gatewayAddress .. "_" .. delegateAddress,
			})
		end
	end

	return utils.paginateTableWithCursor(rewardsArray, cursor, "cursorId", limit, sortBy, sortOrder)
end

return epochs
