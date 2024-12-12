--[[
  WeaveDrive Client

]]

local drive = { _version = "0.0.1" }

function drive.getBlock(height)
	local block = io.open("/block/" .. height)
	if not block then
		return nil, "Block Header not found!"
	end
	local size = block:seek("end")
	block:seek("set")
	local headers = require("json").decode(block:read(size))
	block:close()
	return headers
end

function drive.getTx(txId)
	local file = io.open("/tx/" .. txId)
	if not file then
		return nil, "File not found!"
	end
	local size = file:seek("end")
	file:seek("set")
	local contents = require("json").decode(file:read(size))
	file:close()
	return contents
end

function drive.getData(txId)
	local file = io.open("/data/" .. txId)
	if not file then
		return nil, "File not found!"
	end
	local size = file:seek("end")
	file:seek("set")
	local contents = file:read(size)
	file:close()
	return contents
end

return drive
