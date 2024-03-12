local Bit = require(".crypto.util.bit");
local Stream = require(".crypto.util.stream");
local Array = require(".crypto.util.array");

local SHA1 = require(".crypto.digest.sha1");
local SHA2_256 = require(".crypto.digest.sha2_256");

local XOR = Bit.bxor;

local HMAC = function()
    local public = {};
    local blockSize = 64;
    local Digest = nil;
    local outerPadding = {};
    local innerPadding = {}
    local digest;

    public.setBlockSize = function(bytes)
        blockSize = bytes;
        return public;
    end

    public.setDigest = function(digestModule)
        Digest = digestModule;
        digest = Digest();
        return public;
    end

    public.setKey = function(key)
        local keyStream;
        if Digest == nil then
            error("Digest not set");
        end
        if (Array.size(key) > blockSize) then
            keyStream = Stream.fromArray(Digest()
                .update(Stream.fromArray(key))
                .finish()
                .asBytes());
        else
            keyStream = Stream.fromArray(key);
        end

        outerPadding = {};
        innerPadding = {};

        for i = 1, blockSize do
            local byte = keyStream();
            if byte == nil then byte = 0x00; end
            outerPadding[i] = XOR(0x5C, byte);
            innerPadding[i] = XOR(0x36, byte);
        end

        return public;
    end

    public.init = function()
        digest.init()
            .update(Stream.fromArray(innerPadding));
        return public;
    end

    public.update = function(messageStream)
        digest.update(messageStream);
        return public;
    end

    public.finish = function()
        local inner = digest.finish().asBytes();
        digest.init()
            .update(Stream.fromArray(outerPadding))
            .update(Stream.fromArray(inner))
            .finish();

        return public;
    end

    public.asBytes = function()
        return digest.asBytes();
    end

    public.asHex = function()
        return digest.asHex();
    end

    public.asString = function()
        return digest.asString();
    end

    return public;
end

--- @class Array : table
--- @class Stream : table

--- HMAC function for generating a hash-based message authentication code
--- @param data (Stream) - The data to hash and authenticate
--- @param key (Array) - The key to use for the HMAC
--- @param algorithm? (string) - The algorithm to use for the HMAC (sha1, sha256). Defaults to "sha1"
--- @returns table - A table containing the HMAC in bytes, string, and hex formats.
local hmac = function(data, key, algorithm)
    local digest = nil
    if algorithm == "sha1" then
        digest = SHA1.SHA1
    elseif algorithm == "sha256" then
        digest = SHA2_256.SHA2_256
    elseif algorithm == nil then
        digest = SHA1.SHA1
    else
        error("Unsupported algorithm: " .. algorithm)
    end

    local res = HMAC()
                .setBlockSize(32)
                .setDigest(digest)
                .setKey(key)
                .init()
                .update(data)
                .finish()

	return res
end

return {
    hmac = hmac,
    HMAC = HMAC
};