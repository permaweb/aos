local util = require(".crypto.util.init")
local digest = require(".crypto.digest.init")

local crypto = {
    _version = "0.0.1",
    digest = digest,
    utils = util
};

return crypto
