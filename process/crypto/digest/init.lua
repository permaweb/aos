local MD2 = require(".crypto.digest.md2")
local MD4 = require(".crypto.digest.md4")
local MD5 = require(".crypto.digest.md5")
local SHA1 = require(".crypto.digest.sha1")
local SHA2_256 = require(".crypto.digest.sha2_256")
local SHA2_512 = require(".crypto.digest.sha2_512")
local SHA3 = require(".crypto.digest.sha3")
local Blake2b = require(".crypto.digest.blake2b")


local digest = {
    _version = "0.0.1",
    md2 = MD2,
    md4 = MD4,
    md5 = MD5,
    sha1 = SHA1.sha1,
    sha2_256 = SHA2_256.sha2_256,
    sha2_512 = SHA2_512,
    sha3_256 = SHA3.sha3_256,
    sha3_512 = SHA3.sha3_512,
    keccak256 = SHA3.keccak256,
    keccak512 = SHA3.keccak512,
    blake2b = Blake2b
}




return digest
