local issac = require(".crypto.cipher.issac")
local morus = require(".crypto.cipher.morus")

local cipher = {
    _version = "0.0.1",
    issac = issac,
    morus = morus
};

return cipher