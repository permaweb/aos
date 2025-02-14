local balances = require(".src.balances")
local gar = require(".src.gar")
local vaults = require(".src.vaults")
local ao = require("ao")
local token = {}

--- @return mARIO # returns the last computed total supply, this is to avoid recomputing the total supply every time, and only when requested
function token.lastKnownTotalTokenSupply()
	return LastKnownCirculatingSupply
		+ LastKnownLockedSupply
		+ LastKnownStakedSupply
		+ LastKnownDelegatedSupply
		+ LastKnownWithdrawSupply
		+ Balances[ao.id]
end

--- @class BalanceObjectTallies
--- @field numAddressesVaulting number
--- @field numBalanceVaults number
--- @field numBalances number

--- @class GatewayObjectTallies
--- @field numDelegateVaults number
--- @field numDelegatesVaulting number
--- @field numDelegations number
--- @field numDelegates number
--- @field numExitingDelegations number
--- @field numGatewayVaults number
--- @field numGatewaysVaulting number
--- @field numGateways number
--- @field numExitingGateways number

--- @class StateObjectTallies : GatewayObjectTallies, BalanceObjectTallies

--- @class TotalSupplyDetails
--- @field totalSupply number
--- @field circulatingSupply number
--- @field lockedSupply number
--- @field stakedSupply number
--- @field delegatedSupply number
--- @field withdrawSupply number
--- @field protocolBalance number
--- @field stateObjectTallies StateObjectTallies

--- Crawls the state to compute the total supply and update the last known values
--- @return TotalSupplyDetails
function token.computeTotalSupply()
	-- add all the balances
	local totalSupply = 0
	local circulatingSupply = 0
	local lockedSupply = 0
	local stakedSupply = 0
	local delegatedSupply = 0
	local withdrawSupply = 0
	local protocolBalance = balances.getBalance(ao.id)
	local userBalances = balances.getBalancesUnsafe()
	--- @type StateObjectTallies
	local stateObjectTallies = {
		numAddressesVaulting = 0,
		numBalanceVaults = 0,
		numBalances = 0,
		numDelegateVaults = 0,
		numDelegatesVaulting = 0,
		numDelegates = 0,
		numDelegations = 0,
		numExitingDelegations = 0,
		numGatewayVaults = 0,
		numGatewaysVaulting = 0,
		numGateways = 0,
		numExitingGateways = 0,
	}

	-- tally circulating supply
	for walletAddress, balance in pairs(userBalances) do
		-- clean up 0 balances opportunistically
		if balance > 0 then
			circulatingSupply = circulatingSupply + balance
			stateObjectTallies.numBalances = stateObjectTallies.numBalances + 1
		else
			Balances[walletAddress] = nil
		end
	end
	circulatingSupply = circulatingSupply - protocolBalance
	totalSupply = totalSupply + protocolBalance + circulatingSupply

	-- tally supply stashed in gateways and delegates
	local uniqueDelegates = {}
	for _, gateway in pairs(gar.getGatewaysUnsafe()) do
		if gateway.status == "leaving" then
			stateObjectTallies.numExitingGateways = stateObjectTallies.numExitingGateways + 1
		else
			stateObjectTallies.numGateways = stateObjectTallies.numGateways + 1
		end
		totalSupply = totalSupply + gateway.operatorStake + gateway.totalDelegatedStake
		stakedSupply = stakedSupply + gateway.operatorStake
		delegatedSupply = delegatedSupply + gateway.totalDelegatedStake
		for delegateAddress, delegate in pairs(gateway.delegates) do
			if delegate.delegatedStake == 0 then
				stateObjectTallies.numExitingDelegations = stateObjectTallies.numExitingDelegations + 1
			else
				stateObjectTallies.numDelegations = stateObjectTallies.numDelegations + 1
				if not uniqueDelegates[delegateAddress] then
					uniqueDelegates[delegateAddress] = true
					stateObjectTallies.numDelegates = stateObjectTallies.numDelegates + 1
				end
			end

			-- tally delegates' vaults
			for _, vault in pairs(delegate.vaults) do
				stateObjectTallies.numDelegateVaults = stateObjectTallies.numDelegateVaults + 1
				totalSupply = totalSupply + vault.balance
				withdrawSupply = withdrawSupply + vault.balance
			end
			if next(delegate.vaults) then
				stateObjectTallies.numDelegatesVaulting = stateObjectTallies.numDelegatesVaulting + 1
			end
		end
		-- tally gateway's own vaults
		for _, vault in pairs(gateway.vaults) do
			stateObjectTallies.numGatewayVaults = stateObjectTallies.numGatewayVaults + 1
			totalSupply = totalSupply + vault.balance
			withdrawSupply = withdrawSupply + vault.balance
		end
		if next(gateway.vaults) then
			stateObjectTallies.numGatewaysVaulting = stateObjectTallies.numGatewaysVaulting + 1
		end
	end

	-- user vaults
	local userVaults = vaults.getVaultsUnsafe()
	for _, vaultsForAddress in pairs(userVaults) do
		if next(vaultsForAddress) ~= nil then
			stateObjectTallies.numAddressesVaulting = stateObjectTallies.numAddressesVaulting + 1
		end
		-- they may have several vaults; iterate through them
		for _, vault in pairs(vaultsForAddress) do
			stateObjectTallies.numBalanceVaults = stateObjectTallies.numBalanceVaults + 1
			totalSupply = totalSupply + vault.balance
			lockedSupply = lockedSupply + vault.balance
		end
	end

	LastKnownCirculatingSupply = circulatingSupply
	LastKnownLockedSupply = lockedSupply
	LastKnownStakedSupply = stakedSupply
	LastKnownDelegatedSupply = delegatedSupply
	LastKnownWithdrawSupply = withdrawSupply
	TotalSupply = totalSupply
	return {
		totalSupply = totalSupply,
		circulatingSupply = circulatingSupply,
		lockedSupply = lockedSupply,
		stakedSupply = stakedSupply,
		delegatedSupply = delegatedSupply,
		withdrawSupply = withdrawSupply,
		protocolBalance = protocolBalance,
		stateObjectTallies = stateObjectTallies,
	}
end

return token
