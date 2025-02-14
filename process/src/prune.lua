local arns = require(".src.arns")
local gar = require(".src.gar")
local vaults = require(".src.vaults")
local primaryNames = require(".src.primary_names")
local prune = {}

---@class PruneStateResult
---@field prunedRecords table<string, Record>
---@field newGracePeriodRecords table<string, Record>
---@field prunedReturnedNames table<string, ReturnedName>
---@field prunedReserved table<string, ReservedName>
---@field prunedVaults table<string, Vault>
---@field pruneGatewaysResult table<string, table>
---@field prunedPrimaryNamesAndOwners table<string, RemovedPrimaryName[]>
---@field prunedPrimaryNameRequests table<WalletAddress, PrimaryNameRequest>
---@field delegatorsWithFeeReset WalletAddress[]

--- Prunes the state
--- @param timestamp number The timestamp
--- @param msgId string The message ID
--- @param lastGracePeriodEntryEndTimestamp number The end timestamp of the last known record to enter grace period
--- @return PruneStateResult pruneStateResult - the result of the state pruning
function prune.pruneState(timestamp, msgId, lastGracePeriodEntryEndTimestamp)
	local prunedRecords, newGracePeriodRecords = arns.pruneRecords(timestamp, lastGracePeriodEntryEndTimestamp)
	-- for all the pruned records, create returned names and remove primary name claims
	local prunedPrimaryNamesAndOwners = {}
	for name, _ in pairs(prunedRecords) do
		-- remove primary names
		local removedPrimaryNamesAndOwners = primaryNames.removePrimaryNamesForBaseName(name)
		if #removedPrimaryNamesAndOwners > 0 then
			prunedPrimaryNamesAndOwners[name] = removedPrimaryNamesAndOwners
		end
		-- create returned names for records that have finally expired
		arns.createReturnedName(name, timestamp, ao.id)
	end
	local prunedPrimaryNameRequests = primaryNames.prunePrimaryNameRequests(timestamp)
	local prunedReturnedNames = arns.pruneReturnedNames(timestamp)
	local prunedReserved = arns.pruneReservedNames(timestamp)
	local prunedVaults = vaults.pruneVaults(timestamp)
	local pruneGatewaysResult = gar.pruneGateways(timestamp, msgId)
	local delegatorsWithFeeReset = gar.pruneRedelegationFeeData(timestamp)

	return {
		prunedRecords = prunedRecords,
		newGracePeriodRecords = newGracePeriodRecords,
		prunedReturnedNames = prunedReturnedNames,
		prunedReserved = prunedReserved,
		prunedVaults = prunedVaults,
		pruneGatewaysResult = pruneGatewaysResult,
		prunedPrimaryNamesAndOwners = prunedPrimaryNamesAndOwners,
		prunedPrimaryNameRequests = prunedPrimaryNameRequests,
		delegatorsWithFeeReset = delegatorsWithFeeReset,
	}
end

return prune
