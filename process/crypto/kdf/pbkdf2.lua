local Bit = require(".crypto.util.bit");
local Array = require(".crypto.util.array");
local Stream = require(".crypto.util.stream");
local HMAC = require(".crypto.mac.hmac")

local SHA1 = require(".crypto.digest.sha1");
local SHA2_256 = require(".crypto.digest.sha2_256");

local AND = Bit.band;
local RSHIFT = Bit.rshift;

local word2bytes = function(word)
    local b0, b1, b2, b3;
    b3 = AND(word, 0xFF); word = RSHIFT(word, 8);
    b2 = AND(word, 0xFF); word = RSHIFT(word, 8);
    b1 = AND(word, 0xFF); word = RSHIFT(word, 8);
    b0 = AND(word, 0xFF);
    return b0, b1, b2, b3;
end

local PBKDF2 = function()

    local public = {};

    local blockLen = 16;
    local dKeyLen = 256;
    local iterations = 4096;

    local salt;
    local password;


    local PRF;

    local dKey;


    public.setBlockLen = function(len)
        blockLen = len;
        return public;
    end

    public.setDKeyLen = function(len)
        dKeyLen = len
        return public;
    end

    public.setIterations = function(iter)
        iterations = iter;
        return public;
    end

    public.setSalt = function(saltBytes)
        salt = saltBytes;
        return public;
    end

    public.setPassword = function(passwordBytes)
        password = passwordBytes;
        return public;
    end

    public.setPRF = function(prf)
        PRF = prf;
        return public;
    end

    local buildBlock = function(i)
        local b0, b1, b2, b3 = word2bytes(i);
        local ii = {b0, b1, b2, b3};
        local s = Array.concat(salt, ii);

        local out = {};

        PRF.setKey(password);
        for c = 1, iterations do
            PRF.init()
                .update(Stream.fromArray(s));

            s = PRF.finish().asBytes();
            if(c > 1) then
                out = Array.XOR(out, s);
            else
                out = s;
            end
        end

        return out;
    end

    public.finish = function()
        local blocks = math.ceil(dKeyLen / blockLen);

        dKey = {};

        for b = 1, blocks do
            local block = buildBlock(b);
            dKey = Array.concat(dKey, block);
        end

        if(Array.size(dKey) > dKeyLen) then dKey = Array.truncate(dKey, dKeyLen); end

        return public;
    end

    public.asBytes = function()
        return dKey;
    end

    public.asHex = function()
        return Array.toHex(dKey);
    end

    public.asString = function()
        return Array.toString(dKey);
    end

    return public;
end

--- @class Array : table

--- PBKDF2 key derivation function
--- @param password (Array) - The password to derive the key from
--- @param salt (Array) - The salt to use
--- @param iterations number - The number of iterations to perform
--- @param keyLen number - The length of the key to derive
--- @param digest? string - The digest algorithm to use (sha1, sha256). Defaults to sha1.
--- @returns string - The derived key
local pbkdf2 = function(password, salt, iterations, keyLen, digest)
    local Digest = nil
    if digest == "sha1" then
        Digest = SHA1.SHA1
    elseif digest == "sha256" then
        Digest = SHA2_256.SHA2_256
    elseif digest == nil then
        Digest = SHA1.SHA1
    else
        error("Unsupported algorithm: " .. digest)
    end

    local prf = HMAC.HMAC().setBlockSize(64).setDigest(Digest);

    local res = PBKDF2()
            .setPRF(prf)
            .setBlockLen(16)
            .setDKeyLen(keyLen)
            .setIterations(iterations)
            .setSalt(salt)
            .setPassword(password)
            .finish()

    return res
end

return {
    PBKDF2 = PBKDF2,
    pbkdf2 = pbkdf2
};