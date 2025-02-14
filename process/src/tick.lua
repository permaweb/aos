local epochs = require(".src.epochs")
local gar = require(".src.gar")
local tick = {}

--- @class TickResult
--- @field maybeNewEpoch PrescribedEpoch | nil The new epoch
--- @field maybePrescribedEpoch PrescribedEpoch | nil The prescribed epoch
--- @field maybeDistributedEpoch DistributedEpoch | nil The distributed epoch
--- @field maybeDemandFactor number | nil The demand factor
--- @field pruneGatewaysResult PruneGatewaysResult The prune gateways result

--- Ticks an epoch. A tick is the process of updating the demand factor, distributing rewards, pruning gateways, and creating a new epoch.
--- @param currentTimestamp number The current timestamp
--- @param currentBlockHeight number The current block height
--- @param currentHashchain string The current hashchain
--- @param currentMsgId string The current message ID
--- @param epochIndexToTick number The epoch index to tick
--- @return TickResult # The ticked epoch
function tick.tickEpoch(currentTimestamp, currentBlockHeight, currentHashchain, currentMsgId, epochIndexToTick)
	if currentTimestamp < epochs.getSettings().epochZeroStartTimestamp then
		print("Genesis epoch has not started yet, skipping tick")
		return {
			maybeNewEpoch = nil,
			maybePrescribedEpoch = nil,
			maybeDistributedEpoch = nil,
		}
	end
	-- distribute rewards for the epoch and increments stats for gateways, this closes the epoch if the timestamp is greater than the epochs required distribution timestamp
	local distributedEpoch = epochs.distributeEpoch(epochIndexToTick, currentTimestamp)
	-- prune any gateway that has hit the failed 30 consecutive epoch threshold after the epoch has been distributed
	local pruneGatewaysResult = gar.pruneGateways(currentTimestamp, currentMsgId)
	-- now create the new epoch with the current message hashchain and block height
	local newPrescribedEpoch = epochs.createAndPrescribeNewEpoch(currentTimestamp, currentBlockHeight, currentHashchain)
	return {
		maybeDistributedEpoch = distributedEpoch,
		maybeNewEpoch = newPrescribedEpoch,
		pruneGatewaysResult = pruneGatewaysResult,
	}
end

return tick
