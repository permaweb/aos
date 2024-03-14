local Hmac = require(".crypto.mac.hmac")

local mac = {
    _version = "0.0.1",
    createHmac = Hmac.hmac,
};

return mac