local issac = require(".crypto.cipher.issac")
local morus = require(".crypto.cipher.morus")
local aes = require(".crypto.cipher.aes")
local norx = require(".crypto.cipher.norx")

local cipher = {
    _version = "0.0.1",
    issac = issac,
    morus = morus,
    aes = aes,
    norx = norx
};

return cipher