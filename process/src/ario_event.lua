local AOEvent = require(".src.ao_event")
local utils = require(".src.utils")

--- @alias ARIOEvent AOEvent

--- Convenience factory function for pre populating analytic and msg fields into AOEvents
--- @param msg table
--- @param initialData table<string, any> | nil Optional initial data to populate the event with.
--- @returns ARIOEvent
local function ARIOEvent(msg, initialData)
	local event = AOEvent({
		Cron = msg.Cron or false,
		Cast = msg.Cast or false,
	})
	event:addFields(msg.Tags or {})
	event:addFieldsIfExist(msg, { "From", "Timestamp", "Action" })
	event:addField("Message-Id", msg.Id)
	event:addField("From-Formatted", utils.formatAddress(msg.From))
	event:addField("Memory-KiB-Used", collectgarbage("count"), false)
	if initialData ~= nil then
		event:addFields(initialData)
	end
	return event
end

return ARIOEvent
