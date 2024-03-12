local Stream = require(".crypto.util.stream")
local Hex = require(".crypto.util.hex")
local Array = require(".crypto.util.array")

-- Ciphers
local AES128Cipher = require(".crypto.cipher.aes128")
local AES192Cipher = require(".crypto.cipher.aes192")
local AES256Cipher = require(".crypto.cipher.aes256")

-- Modes
local CBCMode = require(".crypto.cipher.mode.cbc")
local ECBMode = require(".crypto.cipher.mode.ecb")
local CFBMode = require(".crypto.cipher.mode.cfb")
local OFBMode = require(".crypto.cipher.mode.ofb")
local CTRMode = require(".crypto.cipher.mode.ctr")

-- Padding
local ZeroPadding = require(".crypto.padding.zero")

local public = {}

local getBlockCipher = function(keyLength)
    if keyLength == 128 then
        return AES128Cipher
    elseif keyLength == 192 then
        return AES192Cipher
    elseif keyLength == 256 then
        return AES256Cipher
    elseif keyLength == nil then
        return AES128Cipher
    else
        return nil
    end
end

local getMode = function(mode)
    if mode == "CBC" then
        return CBCMode
    elseif mode == "ECB" then
        return ECBMode
    elseif mode == "CFB" then
        return CFBMode
    elseif mode == "OFB" then
        return OFBMode
    elseif mode == "CTR" then
        return CTRMode
    else
        return nil
    end
end


--- Encrypts the given data using AES encryption.
--- @param data string - The data to be encrypted.
--- @param key string - The key to use for encryption.
--- @param iv? string (optional) - The initialization vector to use for encryption. Defaults to 16 null bytes.
--- @param mode? string (optional) - The mode to use for encryption. Defaults to "CBC".
--- @param keyLength? number (optional) - The length of the key to use for encryption. Defaults to 128.
--- @returns table - A table containing the encrypted data in bytes, hex, and string formats.
public.encrypt = function(data, key, iv, mode, keyLength)
    local d = Array.fromString(data)
    local k = Array.fromString(key)
    local _iv = iv ~= nil and Array.fromString(iv) or Array.fromHex("00000000000000000000000000000000")

    local cipherMode = getMode(mode) or CBCMode
    local blockCipher = getBlockCipher(keyLength) or AES128Cipher

    local cipher = cipherMode.Cipher()
        .setKey(k)
        .setBlockCipher(blockCipher)
        .setPadding(ZeroPadding);


    local cipherOutput = cipher
        .init()
        .update(Stream.fromArray(_iv))
        .update(Stream.fromArray(d))
        .finish()

    local results = {}

    results.asBytes = function()
        return cipherOutput.asBytes()
    end

    results.asHex = function()
        return cipherOutput.asHex()
    end

    results.asString = function()
        return cipherOutput.asString()
    end

    return results
end

--- Decrypts the given data using AES decryption.
--- @param cipher string - The hex encoded cipher to be decrypted.
--- @param key string - The key to use for decryption.
--- @param iv? string (optional) - The initialization vector to use for decryption. Defaults to 16 null bytes.
--- @param mode? string (optional) - The mode to use for decryption. Defaults to "CBC".
--- @param keyLength? number (optional) - The length of the key to use for decryption. Defaults to 128.
public.decrypt = function(cipher, key, iv, mode, keyLength)
    local cipherText = Array.fromHex(cipher)
    local k = Array.fromString(key)
    local _iv = iv ~= nil and Array.fromString(iv) or Array.fromHex("00000000000000000000000000000000")

    local cipherMode = getMode(mode) or CBCMode
    local blockCipher = getBlockCipher(keyLength) or AES128Cipher


    local decipher = cipherMode.Decipher()
            .setKey(k)
            .setBlockCipher(blockCipher)
            .setPadding(ZeroPadding);


    local plainOutput = decipher
        .init()
        .update(Stream.fromArray(_iv))
        .update(Stream.fromArray(cipherText))
        .finish()

    local results = {}

    results.asBytes = function()
        return plainOutput.asBytes()
    end

    results.asHex = function()
        return plainOutput.asHex()
    end

    results.asString = function()
        return plainOutput.asString()
    end

    return results
end


return public
