-- arns.lua
local utils = require(".src.utils")
local constants = require(".src.constants")
local balances = require(".src.balances")
local demand = require(".src.demand")
local gar = require(".src.gar")
local arns = {}

--- @class NameRegistry
--- @field reserved table<string, ReservedName> The reserved names
--- @field records table<string, Record> The records
--- @field returned table<string, ReturnedName> The returned records

--- @class StoredRecord
--- @field processId string The process id of the record
--- @field startTimestamp number The start timestamp of the record
--- @field type 'lease' | 'permabuy' The type of the record (lease/permabuy)
--- @field undernameLimit number The undername limit of the record
--- @field purchasePrice number The purchase price of the record
--- @field endTimestamp number|nil The end timestamp of the record

--- @class Record : StoredRecord
--- @field name string The name of the record

--- @class ReservedName
--- @field name string The name of the reserved record
--- @field target string|nil The address of the target of the reserved record
--- @field endTimestamp number|nil The time at which the record is no longer reserved

--- @class ReturnedName -- Returned name saved into the registry
--- @field name string The name of the returned record
--- @field initiator WalletAddress
--- @field startTimestamp Timestamp -- The timestamp of when the record was returned

--- @class ReturnedNameData -- Returned name with endTimestamp and premiumMultiplier
--- @field name string The name of the returned record
--- @field initiator WalletAddress
--- @field startTimestamp Timestamp -- The timestamp of when the record was returned
--- @field endTimestamp Timestamp -- The timestamp of when the record will no longer be in the returned period
--- @field premiumMultiplier number -- The current multiplier for the returned name

--- @class ReturnedNameBuyRecordResult -- extends above
--- @field initiator WalletAddress
--- @field rewardForProtocol mARIO -- The reward for the protocol from the returned name purchase
--- @field rewardForInitiator mARIO -- The reward for the protocol from the returned name purchase

--- @class RecordInteractionResult
--- @field record Record The updated record
--- @field baseRegistrationFee number The base registration fee
--- @field remainingBalance number The remaining balance
--- @field protocolBalance number The protocol balance
--- @field df table The demand factor info
--- @field fundingPlan FundingPlan The funding plan
--- @field fundingResult table The funding result
--- @field totalFee mARIO The total fee for the name-related operation

--- @class BuyNameResult : RecordInteractionResult
--- @field recordsCount number The total number of records
--- @field reservedRecordsCount number The total number of reserved records
--- @field returnedName nil|ReturnedNameBuyRecordResult -- The initiator and reward details if returned name was purchased

--- Buys a record
--- @param name string The name of the record
--- @param purchaseType string The purchase type (lease/permabuy)
--- @param years number|nil The number of years
--- @param from string The address of the sender
--- @param timestamp number The current timestamp
--- @param processId string The process id
--- @param msgId string The current message id
--- @param fundFrom string|nil The intended payment sources; one of "any", "balance", or "stake". Default "balance"
--- @param allowUnsafeProcessId boolean|nil Whether to allow unsafe processIds. Default false.
--- @return BuyNameResult # The result including relevant metadata about the purchase
function arns.buyRecord(name, purchaseType, years, from, timestamp, processId, msgId, fundFrom, allowUnsafeProcessId)
	fundFrom = fundFrom or "balance"
	allowUnsafeProcessId = allowUnsafeProcessId or false
	arns.assertValidBuyRecord(name, years, purchaseType, processId, allowUnsafeProcessId)
	if purchaseType == nil then
		purchaseType = "lease" -- set to lease by default
	end

	if not years and purchaseType == "lease" then
		years = 1 -- set to 1 year by default
	end
	local numYears = purchaseType == "lease" and (years or 1) or 0

	local baseRegistrationFee = demand.baseFeeForNameLength(#name)

	local tokenCostResult = arns.getTokenCost({
		currentTimestamp = timestamp,
		intent = "Buy-Name",
		name = name,
		purchaseType = purchaseType,
		years = numYears,
		from = from,
	})

	local totalFee = tokenCostResult.tokenCost

	local fundingPlan = gar.getFundingPlan(from, totalFee, fundFrom)
	assert(fundingPlan and fundingPlan.shortfall == 0 or false, "Insufficient balances")

	local record = arns.getRecord(name)
	local isPermabuy = record ~= nil and record.type == "permabuy"
	local isActiveLease = record ~= nil and (record.endTimestamp or 0) + constants.GRACE_PERIOD_DURATION_MS > timestamp

	assert(not isPermabuy and not isActiveLease, "Name is already registered")

	assert(not arns.getReservedName(name) or arns.getReservedName(name).target == from, "Name is reserved")

	--- @type StoredRecord
	local newRecord = {
		processId = processId,
		startTimestamp = timestamp,
		type = purchaseType,
		undernameLimit = constants.DEFAULT_UNDERNAME_COUNT,
		purchasePrice = totalFee,
		endTimestamp = purchaseType == "lease" and timestamp + constants.yearsToMs(numYears) or nil,
	}

	-- Register the leased or permanently owned name
	local fundingResult = gar.applyFundingPlan(fundingPlan, msgId, timestamp)
	assert(fundingResult.totalFunded == totalFee, "Funding plan application failed")

	local rewardForProtocol = totalFee
	local rewardForInitiator = 0
	local returnedName = arns.getReturnedName(name)
	if returnedName then
		arns.removeReturnedName(name)
		rewardForInitiator = returnedName.initiator ~= ao.id and math.floor(totalFee * 0.5) or 0
		rewardForProtocol = totalFee - rewardForInitiator
		balances.increaseBalance(returnedName.initiator, rewardForInitiator)
	end

	-- Transfer tokens to the protocol balance
	balances.increaseBalance(ao.id, rewardForProtocol)
	arns.addRecord(name, newRecord)
	demand.tallyNamePurchase(totalFee)
	return {
		record = arns.getRecord(name),
		totalFee = totalFee,
		baseRegistrationFee = baseRegistrationFee,
		remainingBalance = balances.getBalance(from),
		protocolBalance = balances.getBalance(ao.id),
		recordsCount = utils.lengthOfTable(NameRegistry.records),
		reservedRecordsCount = utils.lengthOfTable(NameRegistry.reserved),
		df = demand.getDemandFactorInfo(),
		fundingPlan = fundingPlan,
		fundingResult = fundingResult,
		returnedName = returnedName and {
			initiator = returnedName.initiator,
			rewardForProtocol = rewardForProtocol,
			rewardForInitiator = rewardForInitiator,
		} or nil,
	}
end

--- Adds a record to the registry
--- @param name string The name of the record
--- @param record StoredRecord The record to the name registry
function arns.addRecord(name, record)
	NameRegistry.records[name] = record

	-- remove reserved name if it exists in reserved
	if arns.getReservedName(name) then
		NameRegistry.reserved[name] = nil
	end

	if record.endTimestamp then
		arns.scheduleNextRecordsPrune(record.endTimestamp)
	end
end

--- Gets paginated records
--- @param cursor string|nil The cursor to paginate from
--- @param limit number The limit of records to return
--- @param sortBy string The field to sort by
--- @param sortOrder string The order to sort by
--- @return PaginatedTable<Record> The paginated records
function arns.getPaginatedRecords(cursor, limit, sortBy, sortOrder)
	--- @type Record[]
	local recordsArray = {}
	local cursorField = "name" -- the cursor will be the name
	for name, record in pairs(arns.getRecordsUnsafe()) do
		local recordCopy = utils.deepCopy(record)
		--- @diagnostic disable-next-line: inject-field
		recordCopy.name = name
		table.insert(recordsArray, recordCopy)
	end

	return utils.paginateTableWithCursor(recordsArray, cursor, cursorField, limit, sortBy, sortOrder)
end

--- Get paginated reserved names
--- @param cursor string|nil The cursor to paginate from
--- @param limit number The limit of reserved names to return
--- @param sortBy string The field to sort by
--- @param sortOrder string The order to sort by
--- @return PaginatedTable<ReservedName> The paginated reserved names
function arns.getPaginatedReservedNames(cursor, limit, sortBy, sortOrder)
	--- @type ReservedName[]
	local reservedArray = {}
	local cursorField = "name" -- the cursor will be the name
	for name, reservedName in pairs(arns.getReservedNamesUnsafe()) do
		local reservedNameCopy = utils.deepCopy(reservedName)
		reservedNameCopy.name = name
		table.insert(reservedArray, reservedNameCopy)
	end
	return utils.paginateTableWithCursor(reservedArray, cursor, cursorField, limit, sortBy, sortOrder)
end

--- Extends the lease for a record
--- @param from string The address of the sender
--- @param name string The name of the record
--- @param years number The number of years to extend the lease
--- @param currentTimestamp number The current timestamp
--- @param msgId string The current message id
--- @param fundFrom string|nil The intended payment sources; one of "any", "balance", or "stake". Default "balance"
--- @return RecordInteractionResult # The response including relevant metadata about the lease extension
function arns.extendLease(from, name, years, currentTimestamp, msgId, fundFrom)
	fundFrom = fundFrom or "balance"
	local record = arns.getRecord(name)
	assert(record, "Name is not registered")
	-- throw error if invalid
	arns.assertValidExtendLease(record, currentTimestamp, years)
	local baseRegistrationFee = demand.baseFeeForNameLength(#name)
	local tokenCostResult = arns.getTokenCost({
		currentTimestamp = currentTimestamp,
		intent = "Extend-Lease",
		name = name,
		years = years,
		from = from,
	})
	local totalFee = tokenCostResult.tokenCost

	local fundingPlan = gar.getFundingPlan(from, totalFee, fundFrom)
	assert(fundingPlan and fundingPlan.shortfall == 0 or false, "Insufficient balances")
	local fundingResult = gar.applyFundingPlan(fundingPlan, msgId, currentTimestamp)
	assert(fundingResult.totalFunded == totalFee, "Funding plan application failed")

	-- modify the record with the new end timestamp
	arns.modifyRecordEndTimestamp(name, record.endTimestamp + constants.yearsToMs(years))

	-- Transfer tokens to the protocol balance
	balances.increaseBalance(ao.id, totalFee)
	demand.tallyNamePurchase(totalFee)

	return {
		record = arns.getRecord(name),
		totalFee = totalFee,
		baseRegistrationFee = baseRegistrationFee,
		remainingBalance = balances.getBalance(from),
		protocolBalance = balances.getBalance(ao.id),
		df = demand.getDemandFactorInfo(),
		fundingPlan = fundingPlan,
		fundingResult = fundingResult,
	}
end

--- Calculates the extension fee for a given base fee, years, and demand factor
--- @param baseFee number The base fee for the name
--- @param years number The number of years
--- @param demandFactor number The demand factor
--- @return number The extension fee
function arns.calculateExtensionFee(baseFee, years, demandFactor)
	local extensionFee = arns.calculateAnnualRenewalFee(baseFee, years)
	return math.floor(demandFactor * extensionFee)
end

--- Increases the undername limit for a record
--- @param from string The address of the sender
--- @param name string The name of the record
--- @param qty number The quantity to increase the undername limit by
--- @param currentTimestamp number The current timestamp
--- @param msgId string The current message id
--- @param fundFrom string|nil The intended payment sources; one of "any", "balance", or "stake". Default "balance"
--- @return RecordInteractionResult # The result
function arns.increaseUndernameLimit(from, name, qty, currentTimestamp, msgId, fundFrom)
	fundFrom = fundFrom or "balance"
	-- validate record can increase undernames
	local record = arns.getRecord(name)

	assert(record, "Name is not registered")

	local increaseUndernameCost = arns.getTokenCost({
		currentTimestamp = currentTimestamp,
		intent = "Increase-Undername-Limit",
		name = name,
		quantity = qty,
		type = record.type,
		from = from,
	})

	assert(increaseUndernameCost.tokenCost >= 0, "Invalid undername cost")
	local fundingPlan = gar.getFundingPlan(from, increaseUndernameCost.tokenCost, fundFrom)
	assert(fundingPlan and fundingPlan.shortfall == 0 or false, "Insufficient balances")
	local fundingResult = gar.applyFundingPlan(fundingPlan, msgId, currentTimestamp)
	assert(fundingResult.totalFunded == increaseUndernameCost.tokenCost, "Funding plan application failed")

	-- update the record with the new undername count
	arns.modifyRecordUndernameLimit(name, qty)

	-- Transfer tokens to the protocol balance
	balances.increaseBalance(ao.id, increaseUndernameCost.tokenCost)
	demand.tallyNamePurchase(increaseUndernameCost.tokenCost)
	return {
		record = arns.getRecord(name),
		totalFee = increaseUndernameCost.tokenCost,
		baseRegistrationFee = demand.baseFeeForNameLength(#name),
		remainingBalance = balances.getBalance(from),
		protocolBalance = balances.getBalance(ao.id),
		recordsCount = utils.lengthOfTable(NameRegistry.records),
		reservedRecordsCount = utils.lengthOfTable(NameRegistry.reserved),
		df = demand.getDemandFactorInfo(),
		fundingPlan = fundingPlan,
		fundingResult = fundingResult,
	}
end

--- Gets a record
--- @param name string The name of the record
--- @return StoredRecord|nil # A deep copy of the record or nil if it does not exist
function arns.getRecord(name)
	return utils.deepCopy(NameRegistry.records[name])
end

function arns.getProcessIdForRecord(name)
	local record = arns.getRecord(name)
	return record ~= nil and record.processId or nil
end

--- Gets the active ARNS names between two timestamps
--- @param startTimestamp number The start timestamp
--- @param endTimestamp number The end timestamp
--- @return table<string> The active ARNS names between the two timestamps
function arns.getActiveArNSNamesBetweenTimestamps(startTimestamp, endTimestamp)
	local records = arns.getRecordsUnsafe()
	local activeNames = {}
	for name, record in pairs(records) do
		if arns.recordIsActive(record, startTimestamp) and arns.recordIsActive(record, endTimestamp) then
			table.insert(activeNames, name)
		end
	end
	return activeNames
end

--- Gets the total number of ARNS names and their status before a specific timestamp
--- @param timestamp number The timestamp to check
--- @return table The total number of ARNS names between the two timestamps
local function getRecordsStatsAtTimestamp(timestamp)
	local totalActiveNames = 0
	local totalGracePeriodNames = 0
	local records = arns.getRecordsUnsafe()

	for _, record in pairs(records) do
		if record.type == "permabuy" then
			totalActiveNames = totalActiveNames + 1
		elseif record.type == "lease" and record.endTimestamp then
			if arns.recordIsActive(record, timestamp) then
				totalActiveNames = totalActiveNames + 1
			elseif arns.recordInGracePeriod(record, timestamp) then
				totalGracePeriodNames = totalGracePeriodNames + 1
			end
		end
	end

	return {
		totalActiveNames = totalActiveNames,
		totalGracePeriodNames = totalGracePeriodNames,
	}
end

--- Gets the total number of reserved names that are active before a specific timestamp
--- @param timestamp number The timestamp to check
--- @return number # The total number of reserved names before the timestamp
local function getReservedNamesAtTimestamp(timestamp)
	local reservedNames = arns.getReservedNamesUnsafe()
	local totalReservedNames = 0
	for _, reservedName in pairs(reservedNames) do
		if not reservedName.endTimestamp or reservedName.endTimestamp >= timestamp then
			totalReservedNames = totalReservedNames + 1
		end
	end
	return totalReservedNames
end

--- Gets the total number of returned names that are active before a specific timestamp
--- @param timestamp number The timestamp to check
--- @return number # The total number of returned names before the timestamp
local function getReturnedNamesAtTimestamp(timestamp)
	local returnedNames = arns.getReturnedNamesUnsafe()
	local totalReturnedNames = 0

	for _, returnedName in pairs(returnedNames) do
		if returnedName.startTimestamp + constants.RETURNED_NAME_DURATION_MS >= timestamp then
			totalReturnedNames = totalReturnedNames + 1
		end
	end
	return totalReturnedNames
end

--- Gets the ARNS stats at a specific timestamp
--- @param timestamp number The timestamp to check
--- @return ArNSStats # The ARNS stats at the timestamp
function arns.getArNSStatsAtTimestamp(timestamp)
	local totalNames = getRecordsStatsAtTimestamp(timestamp)
	local totalReservedNames = getReservedNamesAtTimestamp(timestamp)
	local totalReturnedNames = getReturnedNamesAtTimestamp(timestamp)

	return {
		totalActiveNames = totalNames.totalActiveNames,
		totalGracePeriodNames = totalNames.totalGracePeriodNames,
		totalReservedNames = totalReservedNames,
		totalReturnedNames = totalReturnedNames,
	}
end

--- Gets deep copies of all records
--- @return table<string, StoredRecord> # A deep copy of the records table
function arns.getRecords()
	local records = utils.deepCopy(NameRegistry.records)
	return records or {}
end

--- Gets all records
--- @return table<string, StoredRecord> # The actual records table
function arns.getRecordsUnsafe()
	return NameRegistry and NameRegistry.records or {}
end

--- Gets copies of all reserved names
--- @return table<string, ReservedName> # A deep copy of the reserved names table
function arns.getReservedNames()
	local reserved = utils.deepCopy(NameRegistry.reserved)
	return reserved or {}
end

--- Gets all reserved names
--- @return table<string, ReservedName> # The actual reserved names table
function arns.getReservedNamesUnsafe()
	return NameRegistry and NameRegistry.reserved or {}
end

--- Gets a reserved name
--- @param name string The name of the reserved record
--- @return table|nil # A deep copy of the reserved name or nil if it does not exist
function arns.getReservedName(name)
	return utils.deepCopy(NameRegistry.reserved[name])
end

--- Modifies the undername limit for a record
--- @param name string The name of the record
--- @param qty number The quantity to increase the undername limit by
--- @return StoredRecord|nil # The updated record
function arns.modifyRecordUndernameLimit(name, qty)
	local record = arns.getRecord(name)
	assert(record, "Name is not registered")
	NameRegistry.records[name].undernameLimit = record.undernameLimit + qty
	return arns.getRecord(name)
end

--- Modifies the process id for a record
--- @param name string The name of the record
--- @param processId string The new process id
--- @return StoredRecord|nil # The updated record
function arns.modifyProcessId(name, processId)
	local record = arns.getRecord(name)
	assert(record, "Name is not registered")
	NameRegistry.records[name].processId = processId
	return arns.getRecord(name)
end

--- Modifies the end timestamp for a record
--- @param name string The name of the record
--- @param newEndTimestamp number The new end timestamp
--- @return StoredRecord|nil # The updated record
function arns.modifyRecordEndTimestamp(name, newEndTimestamp)
	local record = arns.getRecord(name)
	assert(record, "Name is not registered")
	local maxLeaseLength = constants.MAX_LEASE_LENGTH_YEARS * constants.yearsToMs(1)
	local maxEndTimestamp = record.startTimestamp + maxLeaseLength
	assert(newEndTimestamp <= maxEndTimestamp, "Cannot extend lease beyond 5 years")
	NameRegistry.records[name].endTimestamp = newEndTimestamp
	-- Guard against the invariant case where record may not expire sooner
	arns.scheduleNextRecordsPrune(newEndTimestamp)
	return arns.getRecord(name)
end

---Calculates the lease fee for a given base fee, years, and demand factor
--- @param baseFee number The base fee for the name
--- @param years number|nil The number of years
--- @param demandFactor number The demand factor
--- @return number leaseFee - the lease fee
function arns.calculateLeaseFee(baseFee, years, demandFactor)
	assert(years, "Years is required for lease")
	local annualRegistrationFee = arns.calculateAnnualRenewalFee(baseFee, years)
	local totalLeaseCost = baseFee + annualRegistrationFee
	return math.floor(demandFactor * totalLeaseCost)
end

---Calculates the annual renewal fee for a given base fee and years
--- @param baseFee number The base fee for the name
--- @param years number The number of years
--- @return number annualRenewalFee - the annual renewal fee
function arns.calculateAnnualRenewalFee(baseFee, years)
	local totalAnnualRenewalCost = baseFee * constants.ANNUAL_PERCENTAGE_FEE * years
	return math.floor(totalAnnualRenewalCost)
end

---Calculates the permabuy fee for a given base fee and demand factor
--- @param baseFee number The base fee for the name
--- @param demandFactor number The demand factor
--- @return number permabuyFee - the permabuy fee
function arns.calculatePermabuyFee(baseFee, demandFactor)
	local permabuyPrice = baseFee + arns.calculateAnnualRenewalFee(baseFee, constants.PERMABUY_LEASE_FEE_LENGTH_YEARS)
	return math.floor(demandFactor * permabuyPrice)
end

---Calculates the registration fee for a given purchase type, base fee, years, and demand factor
--- @param purchaseType string The purchase type (lease/permabuy)
--- @param baseFee number The base fee for the name
--- @param years number|nil The number of years, may be empty for permabuy
--- @param demandFactor number The demand factor
--- @return number registrationFee - the registration fee
function arns.calculateRegistrationFee(purchaseType, baseFee, years, demandFactor)
	assert(purchaseType == "lease" or purchaseType == "permabuy", "Invalid purchase type")
	local registrationFee = purchaseType == "lease" and arns.calculateLeaseFee(baseFee, years, demandFactor)
		or arns.calculatePermabuyFee(baseFee, demandFactor)

	return registrationFee
end

---Calculates the undername cost for a given base fee, increase quantity, registration type, years, and demand factor
--- @param baseFee number The base fee for the name
--- @param increaseQty number The increase quantity
--- @param registrationType string The registration type (lease/permabuy)
--- @param demandFactor number The demand factor
--- @return number undernameCost - the undername cost
function arns.calculateUndernameCost(baseFee, increaseQty, registrationType, demandFactor)
	assert(registrationType == "lease" or registrationType == "permabuy", "Invalid registration type")
	local undernamePercentageFee = registrationType == "lease" and constants.UNDERNAME_LEASE_FEE_PERCENTAGE
		or constants.UNDERNAME_PERMABUY_FEE_PERCENTAGE
	local totalFeeForQty = baseFee * undernamePercentageFee * increaseQty
	return math.floor(demandFactor * totalFeeForQty)
end

--- Calculates the number of years between two timestamps
--- @param startTimestamp number The start timestamp
--- @param endTimestamp number The end timestamp
--- @return number yearsBetweenTimestamps - the number of years between the two timestamps
function arns.calculateYearsBetweenTimestamps(startTimestamp, endTimestamp)
	local yearsRemainingFloat = (endTimestamp - startTimestamp) / constants.yearsToMs(1)
	return yearsRemainingFloat
end

--- Asserts that a name is a valid ARNS name
--- @param name string The name to check
function arns.assertValidArNSName(name)
	assert(name and type(name) == "string", "Name is required and must be a string.")
	assert(
		#name >= constants.MIN_NAME_LENGTH and #name <= constants.MAX_NAME_LENGTH,
		"Name length is invalid. Must be between "
			.. constants.MIN_NAME_LENGTH
			.. " and "
			.. constants.MAX_NAME_LENGTH
			.. " characters."
	)
	assert(name:match(constants.ARNS_NAME_REGEX), "Name pattern is invalid. Must match " .. constants.ARNS_NAME_REGEX)
end

--- Asserts that a buy record is valid
--- @param name string The name of the record
--- @param years number|nil The number of years to check
--- @param purchaseType string|nil The purchase type to check
--- @param processId string|nil The processId of the record
--- @param allowUnsafeProcessId boolean|nil Whether to allow unsafe processIds. Default false.
function arns.assertValidBuyRecord(name, years, purchaseType, processId, allowUnsafeProcessId)
	allowUnsafeProcessId = allowUnsafeProcessId or false
	arns.assertValidArNSName(name)

	-- assert purchase type if present is lease or permabuy
	assert(purchaseType == nil or purchaseType == "lease" or purchaseType == "permabuy", "Purchase-Type is invalid.")

	if purchaseType == "lease" or purchaseType == nil then
		-- only check on leases (nil is set to lease)
		-- If 'years' is present, validate it as an integer between 1 and 5
		assert(
			years == nil or (type(years) == "number" and years % 1 == 0 and years >= 1 and years <= 5),
			"Years is invalid. Must be an integer between 1 and 5"
		)
	end

	-- assert processId is valid pattern
	assert(type(processId) == "string", "Process id is required and must be a string.")
	assert(utils.isValidAddress(processId, allowUnsafeProcessId), "Process Id must be a valid address.")
end

--- Asserts that a record is valid for extending the lease
--- @param record StoredRecord The record to check
--- @param currentTimestamp number The current timestamp
--- @param years number The number of years to check
function arns.assertValidExtendLease(record, currentTimestamp, years)
	assert(record.type ~= "permabuy", "Name is permanently owned and cannot be extended")
	assert(not arns.recordExpired(record, currentTimestamp), "Name is expired")

	local maxAllowedYears = arns.getMaxAllowedYearsExtensionForRecord(record, currentTimestamp)
	assert(years <= maxAllowedYears, "Cannot extend lease beyond 5 years")
end

--- Calculates the maximum allowed years extension for a record
--- @param record StoredRecord The record to check
--- @param currentTimestamp number The current timestamp
--- @return number The maximum allowed years extension for the record
function arns.getMaxAllowedYearsExtensionForRecord(record, currentTimestamp)
	if not record.endTimestamp then
		return 0
	end

	if
		currentTimestamp > record.endTimestamp
		and currentTimestamp < record.endTimestamp + constants.GRACE_PERIOD_DURATION_MS
	then
		return constants.MAX_LEASE_LENGTH_YEARS
	end

	-- TODO: should we put this as the ceiling? or should we allow people to extend as soon as it is purchased
	local yearsRemainingOnLease = math.ceil((record.endTimestamp - currentTimestamp) / constants.yearsToMs(1))

	-- a number between 0 and 5 (MAX_LEASE_LENGTH_YEARS)
	return constants.MAX_LEASE_LENGTH_YEARS - yearsRemainingOnLease
end

--- @class RegistrationFee
--- @field lease table<number, number> Lease fees by year
--- @field permabuy number Cost for permanent purchase

--- Gets the registration fees for all name lengths and years
--- @return RegistrationFee registrationFees - a table containing registration fees for each name length, with the following structure:
---   - [nameLength]: table The fees for names of this length
---     - lease: table Lease fees by year
---       - ["1"]: number Cost for 1 year lease
---       - ["2"]: number Cost for 2 year lease
---       - ["3"]: number Cost for 3 year lease
---       - ["4"]: number Cost for 4 year lease
---       - ["5"]: number Cost for 5 year lease
---     - permabuy: number Cost for permanent purchase
function arns.getRegistrationFees()
	local fees = {}
	local demandFactor = demand.getDemandFactor()

	for nameLength, baseFee in pairs(demand.getFees()) do
		local feesForNameLength = {
			lease = {},
			permabuy = 0,
		}
		for years = 1, constants.MAX_LEASE_LENGTH_YEARS do
			feesForNameLength.lease[tostring(years)] = arns.calculateLeaseFee(baseFee, years, demandFactor)
		end
		feesForNameLength.permabuy = arns.calculatePermabuyFee(baseFee, demandFactor)
		fees[tostring(nameLength)] = feesForNameLength
	end
	return fees
end

---@class Discount
---@field name string The name of the discount
---@field discountTotal number The discounted cost
---@field multiplier number The multiplier for the discount

---@class TokenCostResult
---@field tokenCost number The token cost in mARIO of the intended action
---@field discounts table|nil The discounts applied to the token cost
---@field returnedNameDetails table|nil The details of anything returned name in the token cost result

--- @class IntendedAction
--- @field purchaseType 'lease' | 'permabuy'|nil The type of purchase (lease/permabuy)
--- @field years number|nil The number of years for lease
--- @field quantity number|nil The quantity for increasing undername limit
--- @field name string The name of the record
--- @field intent string The intended action type (Buy-Name/Extend-Lease/Increase-Undername-Limit/Upgrade-Name/Primary-Name-Request)
--- @field currentTimestamp number The current timestamp
--- @field from string|nil The target address of the intended action
--- @field record StoredRecord|nil The record to perform the intended action on

--- @param intendedAction IntendedAction The intended action to get token cost for
--- @return TokenCostResult tokenCostResult The token cost result of the intended action
function arns.getTokenCost(intendedAction)
	local tokenCost = 0
	local purchaseType = intendedAction.purchaseType or "lease"
	local years = tonumber(intendedAction.years)
	local name = intendedAction.name
	local baseFee = demand.baseFeeForNameLength(#name)
	local intent = intendedAction.intent
	local qty = tonumber(intendedAction.quantity)
	local record = intendedAction.record or arns.getRecord(name)
	local currentTimestamp = tonumber(intendedAction.currentTimestamp)
	local returnedNameDetails = nil

	assert(type(intent) == "string", "Intent is required and must be a string.")
	assert(type(name) == "string", "Name is required and must be a string.")
	if intent == "Buy-Name" then
		-- stub the process id as it is not required for this intent
		local processId = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		arns.assertValidBuyRecord(name, years, purchaseType, processId, false)
		tokenCost = arns.calculateRegistrationFee(purchaseType, baseFee, years, demand.getDemandFactor())
		local returnedName = arns.getReturnedNameUnsafe(name)
		if returnedName then
			local premiumMultiplier =
				arns.getReturnedNamePremiumMultiplier(returnedName.startTimestamp, currentTimestamp)
			returnedNameDetails = {
				name = name,
				initiator = returnedName.initiator,
				startTimestamp = returnedName.startTimestamp,
				endTimestamp = returnedName.startTimestamp + constants.RETURNED_NAME_DURATION_MS,
				premiumMultiplier = premiumMultiplier,
				basePrice = tokenCost,
			}
			tokenCost = math.floor(tokenCost * premiumMultiplier)
		end
	elseif intent == "Extend-Lease" then
		assert(record, "Name is not registered")
		assert(currentTimestamp, "Timestamp is required")
		assert(years, "Years is required")
		arns.assertValidExtendLease(record, currentTimestamp, years)
		tokenCost = arns.calculateExtensionFee(baseFee, years, demand.getDemandFactor())
	elseif intent == "Increase-Undername-Limit" then
		assert(record, "Name is not registered")
		assert(currentTimestamp, "Timestamp is required")
		assert(qty, "Quantity is required for increasing undername limit")
		arns.assertValidIncreaseUndername(record, qty, currentTimestamp)
		tokenCost = arns.calculateUndernameCost(baseFee, qty, record.type, demand.getDemandFactor())
	elseif intent == "Upgrade-Name" then
		assert(record, "Name is not registered")
		assert(currentTimestamp, "Timestamp is required")
		arns.assertValidUpgradeName(record, currentTimestamp)
		tokenCost = arns.calculatePermabuyFee(baseFee, demand.getDemandFactor())
	elseif intent == "Primary-Name-Request" then
		-- primary name requests cost the same as a 1 undername
		assert(record, "Name is not registered")
		assert(currentTimestamp, "Timestamp is required")
		local primaryRequestBaseFee = demand.baseFeeForNameLength(constants.PRIMARY_NAME_REQUEST_DEFAULT_NAME_LENGTH)
		tokenCost = arns.calculateUndernameCost(primaryRequestBaseFee, 1, record.type, demand.getDemandFactor())
	else
		error("Invalid intent: " .. intent)
	end

	local discounts = {}

	-- if the address is eligible for the ArNS discount, apply the discount
	if gar.isEligibleForArNSDiscount(intendedAction.from) then
		local discountTotal = math.floor(tokenCost * constants.GATEWAY_OPERATOR_ARNS_DISCOUNT_PERCENTAGE)
		local discount = {
			name = constants.GATEWAY_OPERATOR_ARNS_DISCOUNT_NAME,
			discountTotal = discountTotal,
			multiplier = constants.GATEWAY_OPERATOR_ARNS_DISCOUNT_PERCENTAGE,
		}
		table.insert(discounts, discount)
		tokenCost = tokenCost - discountTotal
	end

	-- if token Cost is less than 0, throw an error
	assert(tokenCost >= 0, "Invalid token cost for " .. intendedAction.intent)

	return {
		tokenCost = tokenCost,
		discounts = discounts,
		returnedNameDetails = returnedNameDetails,
	}
end

---@class TokenCostAndFundingPlan
---@field tokenCost number The token cost in mARIO of the intended action
---@field discounts table|nil The discounts applied to the token cost
---@field fundingPlan table|nil The funding plan for the intended action
---@field returnedNameDetails table|nil The details of anything returned name in the token cost result

--- Gets the token cost and funding plan for the given intent
--- @param intent string The intent to get the cost and funding plan for
--- @param name string The name to get the cost and funding plan for
--- @param years number The number of years to get the cost and funding plan for
--- @param quantity number The quantity to get the cost and funding plan for
--- @param purchaseType string The purchase type to get the cost and funding plan for
--- @param currentTimestamp number The current timestamp to get the cost and funding plan for
--- @param from string The from address to get the cost and funding plan for
--- @param fundFrom string The fund from address to get the cost and funding plan for
--- @return TokenCostAndFundingPlan tokenCostAndFundingPlan The token cost and funding plan for the given intent
function arns.getTokenCostAndFundingPlanForIntent(
	intent,
	name,
	years,
	quantity,
	purchaseType,
	currentTimestamp,
	from,
	fundFrom
)
	local tokenCostResult = arns.getTokenCost({
		intent = intent,
		name = name,
		years = years,
		quantity = quantity,
		purchaseType = purchaseType,
		currentTimestamp = currentTimestamp,
		from = from,
	})
	local fundingPlan = fundFrom and gar.getFundingPlan(from, tokenCostResult.tokenCost, fundFrom)
	return {
		tokenCost = tokenCostResult.tokenCost,
		fundingPlan = fundingPlan,
		discounts = tokenCostResult.discounts,
		returnedNameDetails = tokenCostResult.returnedNameDetails,
	}
end

--- Asserts that a name is valid for upgrading
--- @param record StoredRecord The record to check
--- @param currentTimestamp number The current timestamp
function arns.assertValidUpgradeName(record, currentTimestamp)
	assert(record.type ~= "permabuy", "Name is permanently owned")
	assert(
		arns.recordIsActive(record, currentTimestamp) or arns.recordInGracePeriod(record, currentTimestamp),
		"Name is expired"
	)
end

--- Upgrades a leased record to permanently owned
--- @param from string The address of the sender
--- @param name string The name of the record
--- @param currentTimestamp number The current timestamp
--- @param msgId string The current message id
--- @param fundFrom string|nil The intended payment sources; one of "any", "balance", or "stakes". Default "balance"
--- @return RecordInteractionResult # the upgraded record with name and record fields
function arns.upgradeRecord(from, name, currentTimestamp, msgId, fundFrom)
	fundFrom = fundFrom or "balance"
	local record = arns.getRecord(name)
	assert(record, "Name is not registered")
	assert(currentTimestamp, "Timestamp is required")
	arns.assertValidUpgradeName(record, currentTimestamp)

	local baseFee = demand.baseFeeForNameLength(#name)
	local tokenCostResult = arns.getTokenCost({
		currentTimestamp = currentTimestamp,
		intent = "Upgrade-Name",
		name = name,
		from = from,
	})
	local totalFee = tokenCostResult.tokenCost

	local fundingPlan = gar.getFundingPlan(from, totalFee, fundFrom)
	assert(fundingPlan and fundingPlan.shortfall == 0 or false, "Insufficient balances")
	local fundingResult = gar.applyFundingPlan(fundingPlan, msgId, currentTimestamp)
	assert(fundingResult.totalFunded == totalFee, "Funding plan application failed")
	balances.increaseBalance(ao.id, totalFee)
	demand.tallyNamePurchase(totalFee)

	record.endTimestamp = nil
	-- figuring out the next prune timestamp would require a full scan of all records anyway so don't reschedule
	record.type = "permabuy"
	record.purchasePrice = totalFee

	NameRegistry.records[name] = record
	return {
		name = name,
		record = record,
		totalFee = totalFee,
		baseRegistrationFee = baseFee,
		remainingBalance = balances.getBalance(from),
		protocolBalance = balances.getBalance(ao.id),
		df = demand.getDemandFactorInfo(),
		fundingPlan = fundingPlan,
		fundingResult = fundingResult,
	}
end

--- Checks if a record is in the grace period
--- @param record StoredRecord The record to check
--- @param timestamp number The timestamp to check
--- @return boolean isInGracePeriod True if the record is in the grace period, false otherwise (active or expired)
function arns.recordInGracePeriod(record, timestamp)
	return record.endTimestamp
			and record.endTimestamp < timestamp
			and record.endTimestamp + constants.GRACE_PERIOD_DURATION_MS > timestamp
		or false
end

--- Checks if a record is expired
--- @param record StoredRecord The record to check
--- @param timestamp number The timestamp to check
--- @return boolean isExpired True if the record is expired, false otherwise (active or in grace period)
function arns.recordExpired(record, timestamp)
	if record.type == "permabuy" then
		return false
	end
	local isActive = arns.recordIsActive(record, timestamp)
	local inGracePeriod = arns.recordInGracePeriod(record, timestamp)
	local expired = not isActive and not inGracePeriod
	return expired
end

--- Checks if a record is active
--- @param record StoredRecord The record to check
--- @param timestamp number The timestamp to check
--- @return boolean isActive True if the record is active, false otherwise (expired or in grace period)
function arns.recordIsActive(record, timestamp)
	if record.type == "permabuy" then
		return true
	end

	-- record starts before the current timestamp and ends after the current timestamp
	return record.startTimestamp
			and record.startTimestamp <= timestamp
			and record.endTimestamp
			and record.endTimestamp >= timestamp
		or false
end

--- Asserts that a record is valid for increasing the undername limit
--- @param record StoredRecord The record to check
--- @param qty number The quantity to check
--- @param currentTimestamp number The current timestamp
function arns.assertValidIncreaseUndername(record, qty, currentTimestamp)
	assert(arns.recordIsActive(record, currentTimestamp), "Name must be active to increase undername limit")
	assert(qty > 0 and utils.isInteger(qty), "Qty is invalid")
end

--- Adds name to the recently returned name list
--- @param name string The name of the returned name
--- @param timestamp number The timestamp of the release
--- @param initiator string The address of the initiator
--- @returns ReturnedName
function arns.createReturnedName(name, timestamp, initiator)
	assert(not arns.getRecord(name), "Name is registered. Returned names can only be created for unregistered names.")
	assert(
		not arns.getReservedName(name),
		"Name is reserved. Returned names can only be created for unregistered names."
	)
	assert(not arns.getReturnedNameUnsafe(name), "Returned name already exists")
	local returnedName = {
		name = name,
		startTimestamp = timestamp,
		initiator = initiator,
	}
	NameRegistry.returned[name] = returnedName
	arns.scheduleNextReturnedNamesPrune(timestamp + constants.RETURNED_NAME_DURATION_MS)
	return returnedName
end

--- Gets a returned name
--- @param name string The name of the returned name
--- @return ReturnedName|nil
function arns.getReturnedNameUnsafe(name)
	return NameRegistry.returned[name]
end

--- Gets a returned name as a deep copy
--- @param name string The name of the returned name
--- @return ReturnedName|nil
function arns.getReturnedName(name)
	return utils.deepCopy(arns.getReturnedNameUnsafe(name))
end

--- Gets all returned names
--- @return table<string, ReturnedName> returnedNames - the returned names
function arns.getReturnedNamesUnsafe()
	return NameRegistry.returned or {}
end

function arns.getReturnedNamePremiumMultiplier(startTimestamp, currentTimestamp)
	assert(currentTimestamp >= startTimestamp, "Current timestamp must be after the start timestamp")
	assert(
		currentTimestamp < startTimestamp + constants.RETURNED_NAME_DURATION_MS,
		"Current timestamp is after the returned name period"
	)
	local timestampDiff = currentTimestamp - startTimestamp
	-- The percentage of the period that has passed e.g: 0.5 if half the period has passed
	local percentageOfReturnedNamePeriodPassed = timestampDiff / constants.RETURNED_NAME_DURATION_MS
	-- Take the inverse so that a fresh returned name has the full multiplier, and a name almost expired has a multiplier close to base price
	local pctOfReturnPeriodRemaining = 1 - percentageOfReturnedNamePeriodPassed

	return constants.RETURNED_NAME_MAX_MULTIPLIER * pctOfReturnPeriodRemaining
end

--- Removes an returnedName by name
--- @param name string The name of the returnedName
--- @return ReturnedName|nil returnedName - the returnedName instance
function arns.removeReturnedName(name)
	local returnedName = arns.getReturnedName(name)
	NameRegistry.returned[name] = nil
	return returnedName
end

--- Removes a record by name
--- @param name string The name of the record
--- @return Record|nil record - the record instance
function arns.removeRecord(name)
	local record = NameRegistry.records[name]
	NameRegistry.records[name] = nil
	return record
end

--- Removes a reserved name by name
--- @param name string The name of the reserved name
--- @return ReservedName|nil reservedName - the reserved name instance
function arns.removeReservedName(name)
	local reserved = NameRegistry.reserved[name]
	NameRegistry.reserved[name] = nil
	return reserved
end

--- Prunes records that have expired
--- @param currentTimestamp number The current timestamp
--- @param lastGracePeriodEntryEndTimestamp number The end timestamp of the last known record to have entered its grace period
--- @return table<string, Record> prunedRecords - the pruned records
--- @return table<string, Record> recordsInGracePeriod - the records that have entered their grace period
function arns.pruneRecords(currentTimestamp, lastGracePeriodEntryEndTimestamp)
	lastGracePeriodEntryEndTimestamp = lastGracePeriodEntryEndTimestamp or 0
	local prunedRecords = {}
	local newGracePeriodRecords = {}
	if not NextRecordsPruneTimestamp or NextRecordsPruneTimestamp > currentTimestamp then
		return prunedRecords, newGracePeriodRecords
	end

	-- identify any records that are leases and that have expired, account for a two week grace period in seconds
	NextRecordsPruneTimestamp = nil

	-- note: use unsafe to avoid copying all the records, but be careful not to modify the records directly here
	for name, record in pairs(arns.getRecordsUnsafe()) do
		if arns.recordExpired(record, currentTimestamp) then
			print("Pruning record " .. name .. " because it has expired")
			prunedRecords[name] = arns.removeRecord(name)
		elseif arns.recordInGracePeriod(record, currentTimestamp) then
			if record.endTimestamp > lastGracePeriodEntryEndTimestamp then
				print(
					"Adding record " .. name .. " to new grace period records because it has entered its grace period"
				)
				newGracePeriodRecords[name] = record
			end
			-- Make sure we prune when the grace period is over
			arns.scheduleNextRecordsPrune(record.endTimestamp + constants.GRACE_PERIOD_DURATION_MS)
		elseif record.endTimestamp then
			arns.scheduleNextRecordsPrune(record.endTimestamp)
		end
	end
	return prunedRecords, newGracePeriodRecords
end

--- Prunes returned names that have expired
--- @param currentTimestamp number The current timestamp
--- @return ReturnedName[] prunedReturnedNames - the pruned returned names
function arns.pruneReturnedNames(currentTimestamp)
	local prunedReturnedNames = {}
	if not NextReturnedNamesPruneTimestamp or currentTimestamp < NextReturnedNamesPruneTimestamp then
		-- No known returned names to prune
		return prunedReturnedNames
	end

	-- reset the next prune timestamp, below will populate it with the next prune timestamp minimum
	NextReturnedNamesPruneTimestamp = nil

	-- note: use unsafe to avoid copying all the returned names, but be careful not to modify the returned names directly here
	for name, returnedName in pairs(arns.getReturnedNamesUnsafe()) do
		local endTimestamp = returnedName.startTimestamp + constants.RETURNED_NAME_DURATION_MS
		if currentTimestamp >= endTimestamp then
			prunedReturnedNames[name] = arns.removeReturnedName(name)
		else
			arns.scheduleNextReturnedNamesPrune(endTimestamp)
		end
	end
	return prunedReturnedNames
end

--- Prunes reserved names that have expired
--- @param currentTimestamp number The current timestamp
--- @return ReservedName[] prunedReservedNames - the pruned reserved names
function arns.pruneReservedNames(currentTimestamp)
	local prunedReserved = {}

	-- note: use unsafe to avoid copying all the reserved names, but be careful not to modify the reserved names directly here
	for name, details in pairs(arns.getReservedNamesUnsafe()) do
		if details.endTimestamp and details.endTimestamp <= currentTimestamp then
			prunedReserved[name] = arns.removeReservedName(name)
		end
	end
	return prunedReserved
end

--- Asserts that a name can be reassigned
--- @param record StoredRecord | nil The record to check
--- @param currentTimestamp number The current timestamp
--- @param from string The address of the sender
--- @param newProcessId string The new process id
--- @param allowUnsafeProcessId boolean|nil Whether to allow unsafe processIds. Default false.
function arns.assertValidReassignName(record, currentTimestamp, from, newProcessId, allowUnsafeProcessId)
	allowUnsafeProcessId = allowUnsafeProcessId or false
	assert(record, "Name is not registered")
	assert(currentTimestamp, "Timestamp is required")
	assert(utils.isValidAddress(newProcessId, allowUnsafeProcessId), "Invalid Process-Id")
	assert(record.processId == from, "Not authorized to reassign this name")

	if record.endTimestamp then
		assert(
			not arns.recordInGracePeriod(record, currentTimestamp),
			"Name must be extended before it can be reassigned"
		)
		assert(not arns.recordExpired(record, currentTimestamp), "Name is expired")
	end

	return true
end

--- Reassigns a name
--- @param name string The name of the record
--- @param from string The address of the sender
--- @param currentTimestamp number The current timestamp
--- @param newProcessId string The new process id
--- @param allowUnsafeProcessId boolean|nil Whether to allow unsafe processIds. Default false.
--- @return StoredRecord|nil updatedRecord - the updated record
function arns.reassignName(name, from, currentTimestamp, newProcessId, allowUnsafeProcessId)
	allowUnsafeProcessId = allowUnsafeProcessId or false
	local record = arns.getRecord(name)
	arns.assertValidReassignName(record, currentTimestamp, from, newProcessId, allowUnsafeProcessId)
	local updatedRecord = arns.modifyProcessId(name, newProcessId)
	return updatedRecord
end

--- @param timestamp Timestamp
function arns.scheduleNextRecordsPrune(timestamp)
	NextRecordsPruneTimestamp = math.min(NextRecordsPruneTimestamp or timestamp, timestamp)
end

--- @param timestamp Timestamp
function arns.scheduleNextReturnedNamesPrune(timestamp)
	NextReturnedNamesPruneTimestamp = math.min(NextReturnedNamesPruneTimestamp or timestamp, timestamp)
end

function arns.nextRecordsPruneTimestamp()
	return NextRecordsPruneTimestamp
end

function arns.nextReturnedNamesPruneTimestamp()
	return NextReturnedNamesPruneTimestamp
end

return arns
