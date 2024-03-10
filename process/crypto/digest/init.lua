local MD2 = require(".crypto.digest.md2")
local MD4 = require(".crypto.digest.md4")
local MD5 = require(".crypto.digest.md5")
local SHA1 = require(".crypto.digest.sha1")
local SHA256 = require(".crypto.digest.sha256")


local digest = {
    _version = "0.0.1",
    md2 = MD2,
    md4 = MD4,
    md5 = MD5,
    sha1 = SHA1,
    sha256 = SHA256
}



return digest
