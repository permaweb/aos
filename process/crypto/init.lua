local util = require(".crypto.util.init")
local digest = require(".crypto.digest.init")
local cipher = require(".crypto.cipher.init")
local crypto = {
    _version = "0.0.1",
    digest = digest,
    utils = util,
    cipher = cipher
};

return crypto