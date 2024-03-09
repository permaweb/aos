local MD2 = require(".crypto.digest.md2")
local Stream = require(".crypto.util.stream")

local utils = {
    stream = Stream
}

local digest = {
    md2 = MD2
}

local crypto = {
    _version = "0.0.1",
    digest = digest,
    utils = utils
};

return crypto
