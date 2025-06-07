--[[
  WeaveDrive Client

]]

local drive = { _version = "0.0.1" }

function drive.getBlock(height)
	local block = io.open("/block/" .. height)
	if not block then
		return nil, "Block Header not found!"
	end
	local headers = require("json").decode(block:read(block:seek("end")))
	block:close()
	return headers
end

function drive.getTx(txId)
	local file = io.open("/tx/" .. txId)
	if not file then
		return nil, "File not found!"
	end
	local contents = require("json").decode(file:read(file:seek("end")))
	file:close()
	return contents
end

function drive.getData(txId)
	local file = io.open("/data/" .. txId)
	if not file then
		return nil, "File not found!"
	end
	local contents = file:read(file:seek("end"))
	file:close()
	return contents
end

return drive
