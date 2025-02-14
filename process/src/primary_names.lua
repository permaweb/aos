local arns = require(".src.arns")
local balances = require(".src.balances")
local utils = require(".src.utils")
local gar = require(".src.gar")
local constants = require(".src.constants")
local primaryNames = {}

--- @alias WalletAddress string
--- @alias ArNSName string

--- @class PrimaryNames
--- @field owners table<WalletAddress, PrimaryName> - map indexed by owner address containing the primary name and all metadata, used for reverse lookups
--- @field names table<ArNSName, WalletAddress> - map indexed by primary name containing the owner address, used for reverse lookups
--- @field requests table<WalletAddress, PrimaryNameRequest> - map indexed by owner address containing the request, used for pruning expired requests

--- @class PrimaryName
--- @field name ArNSName
--- @field startTimestamp number

--- @class PrimaryNameWithOwner
--- @field name ArNSName
--- @field owner WalletAddress
--- @field startTimestamp number

--- @class PrimaryNameInfo
--- @field name ArNSName
--- @field owner WalletAddress
--- @field startTimestamp number
--- @field processId WalletAddress

--- @class PrimaryNameRequest
--- @field name ArNSName -- the name being requested
--- @field startTimestamp number -- the timestamp of the request
--- @field endTimestamp number -- the timestamp of the request expiration

--- @class CreatePrimaryNameResult
--- @field request PrimaryNameRequest|nil
--- @field newPrimaryName PrimaryNameWithOwner|nil
--- @field baseNameOwner WalletAddress
--- @field fundingPlan table
--- @field fundingResult table

local function baseNameForName(name)
	return (name or ""):match("[^_]+$") or name
end

--- Creates a transient request for a primary name. This is done by a user and must be approved by the name owner of the base name.
--- @param name string -- the name being requested, this could be an undername and should always be lower case
--- @param initiator WalletAddress -- the address that is creating the primary name request, e.g. the ANT process id
--- @param timestamp number -- the timestamp of the request
--- @param msgId string -- the message id of the request
--- @param fundFrom "balance"|"stakes"|"any"|nil -- the address to fund the request from. Default is "balance"
--- @return CreatePrimaryNameResult # the request created, or the primary name with owner data if the request is approved
function primaryNames.createPrimaryNameRequest(name, initiator, timestamp, msgId, fundFrom)
	fundFrom = fundFrom or "balance"
	name = string.lower(name)
	local baseName = baseNameForName(name)

	--- check the primary name request for the initiator does not already exist for the same name
	--- this allows the caller to create a new request and pay the fee again, so long as it is for a different name
	local existingRequest = primaryNames.getPrimaryNameRequest(initiator)
	assert(
		not existingRequest or existingRequest.name ~= name,
		"Primary name request by '" .. initiator .. "' for '" .. name .. "' already exists"
	)

	--- check the primary name is not already owned
	local primaryNameOwner = primaryNames.getAddressForPrimaryName(name)
	assert(not primaryNameOwner, "Primary name is already owned")

	local record = arns.getRecord(baseName)
	assert(record, "ArNS record '" .. baseName .. "' does not exist")
	assert(arns.recordIsActive(record, timestamp), "ArNS record '" .. baseName .. "' is not active")

	local requestCost = arns.getTokenCost({
		intent = "Primary-Name-Request",
		name = name,
		currentTimestamp = timestamp,
		record = record,
	})

	local fundingPlan = gar.getFundingPlan(initiator, requestCost.tokenCost, fundFrom)
	assert(fundingPlan and fundingPlan.shortfall == 0, "Insufficient balances")
	local fundingResult = gar.applyFundingPlan(fundingPlan, msgId, timestamp)
	assert(fundingResult.totalFunded == requestCost.tokenCost, "Funding plan application failed")

	--- transfer the primary name cost from the initiator to the protocol balance
	balances.increaseBalance(ao.id, requestCost.tokenCost)

	local request = {
		name = name,
		startTimestamp = timestamp,
		endTimestamp = timestamp + constants.PRIMARY_NAME_REQUEST_DURATION_MS,
	}

	--- if the initiator is base name owner, then just set the primary name and return
	local newPrimaryName
	if record.processId == initiator then
		newPrimaryName = primaryNames.setPrimaryNameFromRequest(initiator, request, timestamp)
	else
		-- otherwise store the request for asynchronous approval
		PrimaryNames.requests[initiator] = request
		primaryNames.scheduleNextPrimaryNamesPruning(request.endTimestamp)
	end

	return {
		request = request,
		newPrimaryName = newPrimaryName,
		baseNameOwner = record.processId,
		fundingPlan = fundingPlan,
		fundingResult = fundingResult,
	}
end

--- Get a primary name request, safely deep copying the request
--- @param address WalletAddress
--- @return PrimaryNameRequest|nil primaryNameClaim - the request found, or nil if it does not exist
function primaryNames.getPrimaryNameRequest(address)
	return utils.deepCopy(primaryNames.getUnsafePrimaryNameRequests()[address])
end

--- Unsafe access to the primary name requests
--- @return table<WalletAddress, PrimaryNameRequest> primaryNameClaims - the primary name requests
function primaryNames.getUnsafePrimaryNameRequests()
	return PrimaryNames.requests or {}
end

function primaryNames.getUnsafePrimaryNames()
	return PrimaryNames.names or {}
end

--- Unsafe access to the primary name owners
--- @return table<WalletAddress, PrimaryName> primaryNames - the primary names
function primaryNames.getUnsafePrimaryNameOwners()
	return PrimaryNames.owners or {}
end

--- @class PrimaryNameRequestApproval
--- @field newPrimaryName PrimaryNameWithOwner
--- @field request PrimaryNameRequest

--- Action taken by the owner of a primary name. This is who pays for the primary name.
--- @param recipient string -- the address that is requesting the primary name
--- @param from string -- the process id that is requesting the primary name for the owner
--- @param timestamp number -- the timestamp of the request
--- @return PrimaryNameRequestApproval # the primary name with owner data and original request
function primaryNames.approvePrimaryNameRequest(recipient, name, from, timestamp)
	local request = primaryNames.getPrimaryNameRequest(recipient)
	assert(request, "Primary name request not found")
	assert(request.endTimestamp > timestamp, "Primary name request has expired")
	assert(name == request.name, "Provided name does not match the primary name request")

	-- assert the process id in the initial request still owns the name
	local baseName = baseNameForName(request.name)
	local record = arns.getRecord(baseName)
	assert(record, "ArNS record '" .. baseName .. "' does not exist")
	assert(record.processId == from, "Primary name request must be approved by the owner of the base name")

	-- set the primary name
	local newPrimaryName = primaryNames.setPrimaryNameFromRequest(recipient, request, timestamp)
	return {
		newPrimaryName = newPrimaryName,
		request = request,
	}
end

--- Update the primary name maps and return the primary name. Removes the request from the requests map.
--- @param recipient string -- the address that is requesting the primary name
--- @param request PrimaryNameRequest
--- @param startTimestamp number
--- @return PrimaryNameWithOwner # the primary name with owner data
function primaryNames.setPrimaryNameFromRequest(recipient, request, startTimestamp)
	--- if the owner has an existing primary name, make sure we remove it from the maps before setting the new one
	local existingPrimaryName = primaryNames.getPrimaryNameDataWithOwnerFromAddress(recipient)
	if existingPrimaryName then
		primaryNames.removePrimaryName(existingPrimaryName.name, recipient)
	end
	PrimaryNames.names[request.name] = recipient
	PrimaryNames.owners[recipient] = {
		name = request.name,
		startTimestamp = startTimestamp,
	}
	PrimaryNames.requests[recipient] = nil
	return {
		name = request.name,
		owner = recipient,
		startTimestamp = startTimestamp,
	}
end

--- @class RemovedPrimaryNameResult
--- @field name string
--- @field owner WalletAddress

--- Remove primary names, returning the results of the name removals
--- @param names string[]
--- @param from string
--- @return RemovedPrimaryNameResult[] removedPrimaryNameResults - the results of the name removals
function primaryNames.removePrimaryNames(names, from)
	local removedPrimaryNamesAndOwners = {}
	for _, name in pairs(names) do
		local removedPrimaryNameAndOwner = primaryNames.removePrimaryName(name, from)
		table.insert(removedPrimaryNamesAndOwners, removedPrimaryNameAndOwner)
	end
	return removedPrimaryNamesAndOwners
end

--- Release a primary name
--- @param name ArNSName -- the name being released
--- @param from WalletAddress -- the address that is releasing the primary name, or the owner of the base name
--- @return RemovedPrimaryNameResult
function primaryNames.removePrimaryName(name, from)
	--- assert the from is the current owner of the name
	local primaryName = primaryNames.getPrimaryNameDataWithOwnerFromName(name)
	assert(primaryName, "Primary name '" .. name .. "' does not exist")
	local baseName = baseNameForName(name)
	local record = arns.getRecord(baseName)
	assert(
		primaryName.owner == from or (record and record.processId == from),
		"Caller is not the owner of the primary name, or the owner of the " .. baseName .. " record"
	)

	PrimaryNames.names[name] = nil
	PrimaryNames.owners[primaryName.owner] = nil
	if PrimaryNames.requests[primaryName.owner] and PrimaryNames.requests[primaryName.owner].name == name then
		PrimaryNames.requests[primaryName.owner] = nil
	end
	return {
		name = name,
		owner = primaryName.owner,
	}
end

--- Get the address for a primary name, allowing for forward lookups (e.g. "foo.bar" -> "0x123")
--- @param name string
--- @return WalletAddress|nil address -- the address for the primary name, or nil if it does not exist
function primaryNames.getAddressForPrimaryName(name)
	return PrimaryNames.names[name]
end

--- Get the name data for an address, allowing for reverse lookups (e.g. "0x123" -> "foo.bar")
--- @param address string
--- @return PrimaryNameInfo|nil -- the primary name with owner data, or nil if it does not exist
function primaryNames.getPrimaryNameDataWithOwnerFromAddress(address)
	local nameData = PrimaryNames.owners[address]

	if not nameData then
		return nil
	end
	return {

		owner = address,
		name = nameData.name,
		startTimestamp = nameData.startTimestamp,
		processId = arns.getProcessIdForRecord(baseNameForName(nameData.name)),
	}
end

--- Complete name resolution, returning the owner and name data for a name
--- @param name string
--- @return PrimaryNameInfo|nil - the primary name with owner data and processId, or nil if it does not exist
function primaryNames.getPrimaryNameDataWithOwnerFromName(name)
	local owner = primaryNames.getAddressForPrimaryName(name)
	if not owner then
		return nil
	end
	local nameData = primaryNames.getPrimaryNameDataWithOwnerFromAddress(owner)
	if not nameData then
		return nil
	end
	return nameData
end

---Finds all primary names with a given base  name
--- @param baseName string -- the base name to find primary names for (e.g. "test" to find "undername_test")
--- @return PrimaryNameWithOwner[] primaryNamesForArNSName - the primary names with owner data
function primaryNames.getPrimaryNamesForBaseName(baseName)
	local primaryNamesForArNSName = {}
	for name, _ in pairs(primaryNames.getUnsafePrimaryNames()) do
		local nameData = primaryNames.getPrimaryNameDataWithOwnerFromName(name)
		if nameData and baseNameForName(name) == baseName then
			table.insert(primaryNamesForArNSName, nameData)
		end
	end
	-- sort by name length
	table.sort(primaryNamesForArNSName, function(a, b)
		return #a.name < #b.name
	end)
	return primaryNamesForArNSName
end

--- @class RemovedPrimaryName
--- @field owner WalletAddress
--- @field name ArNSName

--- Remove all primary names with a given base name
--- @param baseName string
--- @return RemovedPrimaryName[] removedPrimaryNames - the results of the name removals
function primaryNames.removePrimaryNamesForBaseName(baseName)
	local removedNames = {}
	local primaryNamesForBaseName = primaryNames.getPrimaryNamesForBaseName(baseName)
	for _, nameData in pairs(primaryNamesForBaseName) do
		local removedName = primaryNames.removePrimaryName(nameData.name, nameData.owner)
		table.insert(removedNames, removedName)
	end
	return removedNames
end

--- Get paginated primary names
--- @param cursor string|nil
--- @param limit number
--- @param sortBy string
--- @param sortOrder string
--- @return PaginatedTable<PrimaryNameWithOwner> paginatedPrimaryNames - the paginated primary names
function primaryNames.getPaginatedPrimaryNames(cursor, limit, sortBy, sortOrder)
	local primaryNamesArray = {}
	local cursorField = "name"
	for owner, primaryName in pairs(primaryNames.getUnsafePrimaryNameOwners()) do
		table.insert(primaryNamesArray, {
			name = primaryName.name,
			owner = owner,
			startTimestamp = primaryName.startTimestamp,
			processId = arns.getProcessIdForRecord(baseNameForName(primaryName.name)),
		})
	end
	return utils.paginateTableWithCursor(primaryNamesArray, cursor, cursorField, limit, sortBy, sortOrder)
end

--- Get paginated primary name requests
--- @param cursor string|nil
--- @param limit number
--- @param sortBy string
--- @param sortOrder string
--- @return PaginatedTable<PrimaryNameRequest> paginatedPrimaryNameRequests - the paginated primary name requests
function primaryNames.getPaginatedPrimaryNameRequests(cursor, limit, sortBy, sortOrder)
	local primaryNameRequestsArray = {}
	local cursorField = "initiator"
	for initiator, request in pairs(primaryNames.getUnsafePrimaryNameRequests()) do
		table.insert(primaryNameRequestsArray, {
			name = request.name,
			startTimestamp = request.startTimestamp,
			endTimestamp = request.endTimestamp,
			initiator = initiator,
		})
	end
	return utils.paginateTableWithCursor(primaryNameRequestsArray, cursor, cursorField, limit, sortBy, sortOrder)
end

--- Prune expired primary name requests
--- @param timestamp number
--- @return table<string, PrimaryNameRequest> prunedNameClaims - the names of the requests that were pruned
function primaryNames.prunePrimaryNameRequests(timestamp)
	local prunedNameRequests = {}
	if not NextPrimaryNamesPruneTimestamp or timestamp < NextPrimaryNamesPruneTimestamp then
		-- No known requests to prune
		return prunedNameRequests
	end

	-- reset the next prune timestamp, below will populate it with the next prune timestamp minimum
	NextPrimaryNamesPruneTimestamp = nil

	for initiator, request in pairs(primaryNames.getUnsafePrimaryNameRequests()) do
		if request.endTimestamp <= timestamp then
			PrimaryNames.requests[initiator] = nil
			prunedNameRequests[initiator] = request
		else
			primaryNames.scheduleNextPrimaryNamesPruning(request.endTimestamp)
		end
	end
	return prunedNameRequests
end

--- @param timestamp Timestamp
function primaryNames.scheduleNextPrimaryNamesPruning(timestamp)
	NextPrimaryNamesPruneTimestamp = math.min(NextPrimaryNamesPruneTimestamp or timestamp, timestamp)
end

function primaryNames.nextPrimaryNamesPruneTimestamp()
	return NextPrimaryNamesPruneTimestamp
end

return primaryNames
