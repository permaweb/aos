local Hex = require(".crypto.util.hex")

-- tags
local HEADER_TAG  = 0x01
local PAYLOAD_TAG = 0x02
local TRAILER_TAG = 0x04
local FINAL_TAG   = 0x08

local function G(s, a, b, c, d)
	-- The quarter-round.
	-- s is the state: u64[16].
	local A, B, C, D = s[a], s[b], s[c], s[d]
	--
	-- H(): return (a ~ b) ~ ((a & b) << 1) -- INLINED
	-- ROTR64(): return (x >> n) | (x << (64-n)) --INLINED
	--
	A = (A ~ B) ~ ((A & B) << 1)  -- H(A, B);
	D = D ~ A; D = (D >> 8) | (D << (56)) --ROTR64(D, 8) --R0
	C = (C ~ D) ~ ((C & D) << 1)  -- H(C, D);
	B = B ~ C; B = (B >> 19) | (B << (45)) --ROTR64(B, 19) --R1
	A = (A ~ B) ~ ((A & B) << 1)  -- H(A, B);
	D = D ~ A; D = (D >> 40) | (D << (24)) --ROTR64(D, 40) --R2
	C = (C ~ D) ~ ((C & D) << 1)  -- H(C, D);
	B = B ~ C; B = (B >> 63) | (B << (1)) --ROTR64(B, 63) --R3
	s[a], s[b], s[c], s[d] = A, B, C, D
end

local function F(s)
	-- The full round.  s is the state: u64[16]
	--
	-- beware! in Lua, arrays are 1-based indexed, not 0-indexed as in C
    -- Column step
	G(s,  1,  5,  9, 13);
    G(s,  2,  6, 10, 14);
    G(s,  3,  7, 11, 15);
    G(s,  4,  8, 12, 16);
    -- Diagonal step
    G(s,  1,  6, 11, 16);
    G(s,  2,  7, 12, 13);
    G(s,  3,  8,  9, 14);
    G(s,  4,  5, 10, 15);
end

local function permute(s)
	-- the core permutation  (four rounds)
	for _ = 1, 4 do F(s) end
end

local function pad(ins)
	-- pad string ins to length 96 ("BYTES(NORX_R)")
	local out
	local inslen = #ins
	if inslen == 95 then return ins .. '\x81' end -- last byte is 0x01 | 0x80
	-- here inslen is < 95, so must pad with 96-(inslen+2) zeros
	out = ins .. '\x01' .. string.rep('\0', 94-inslen) .. '\x80'
	assert(#out == 96)
	return out
end

local function absorb_block(s, ins, ini, tag)
	-- the input string is the substring of 'ins' starting at position 'ini'
	-- (we cannot use a char* as in C!)
	s[16] = s[16] ~ tag
	permute(s)
	for i = 1, 12 do
		s[i] = s[i] ~ string.unpack("<I8", ins, ini + (i-1)*8)
	end
end

local function absorb_lastblock(s, last, tag)
	absorb_block(s, pad(last), 1, tag)
end

local function encrypt_block(s, out_table, ins, ini)
	-- encrypt block in 'ins' at offset 'ini'
	-- append encrypted chunks at the end of out_table
	s[16] = s[16] ~ PAYLOAD_TAG
	permute(s)
	for i = 1, 12 do
		s[i] = s[i] ~ string.unpack("<I8", ins, ini + (i-1)*8)
		table.insert(out_table, string.pack("<I8", s[i]))
	end
end

local function encrypt_lastblock(s, out_table, last)
	-- encrypt last block
	-- append encrypted last block at the end of out_table
	local t = {} -- encrypted chunks of 'last' will be appended to t
	local lastlen = #last
	last = pad(last)
	encrypt_block(s, t, last, 1)
	last = table.concat(t)
	last = last:sub(1, lastlen)  -- keep only the first lastlen bytes
	table.insert(out_table, last)
end

local function decrypt_block(s, out_table, ins, ini)
	-- decrypt block in 'ins' at offset 'ini'
	-- append decrypted chunks at the end of out_table
	s[16] = s[16] ~ PAYLOAD_TAG
	permute(s)
	for i = 1, 12 do
		local c = string.unpack("<I8", ins, ini + (i-1)*8)
		table.insert(out_table, string.pack("<I8", s[i] ~ c))
		s[i] = c
	end
end

local function decrypt_lastblock(s, out_table, last)
	-- decrypt last block
	-- append decrypted block at the end of out_table
	--
	local lastlen = #last
	s[16] = s[16] ~ PAYLOAD_TAG
	permute(s)
	local byte, char = string.byte, string.char
	local lastblock_s8_table = {} -- last block as an array of 8-byte strings
	for i = 1, 12 do
		local s8 = string.pack("<I8", s[i])
		table.insert(lastblock_s8_table, s8)
	end
	local lastblock = table.concat(lastblock_s8_table) -- lastblock as a 96-byte string
	-- explode lastblock as an array of bytes
	local lastblock_byte_table = {}
	for i = 1, 96 do
		lastblock_byte_table[i] = byte(lastblock, i)
	end
	-- copy last
	for i = 1, lastlen do
		lastblock_byte_table[i] = byte(last, i)
	end
	-- perform the 'xor's
	lastblock_byte_table[lastlen+1] = lastblock_byte_table[lastlen+1] ~ 0x01
	lastblock_byte_table[96] = lastblock_byte_table[96] ~ 0x80
	-- build back lastblock as a string
	local lastblock_char_table = {}
	for i = 1, 96 do
		lastblock_char_table[i] = char(lastblock_byte_table[i])
	end
	lastblock = table.concat(lastblock_char_table) -- lastblock as a 96-byte string
	--
	local t = {}
	for i = 1, 12 do
		local c = string.unpack("<I8", lastblock, 1 + (i-1)*8)
		local x = string.pack("<I8", s[i] ~ c)
		table.insert(t, x)
		s[i] = c
	end
	last = table.concat(t)
	last = last:sub(1, lastlen)  -- keep only the first lastlen bytes
	table.insert(out_table, last)
end

local function init(k, n)
	-- initialize and return the norx state
	-- k: the key as a 32-byte string
	-- n: the nonce as a 32-byte string
	local s = {} -- the norx state: u64[16]
	-- (the two following F(s) could be replaced with a constant table)
	-- (only s[9]..s[16] are needed)
	for i = 1, 16 do s[i] = i-1 end
	F(s)
	F(s)
	-- load the nonce
	s[1], s[2], s[3], s[4] = string.unpack("<I8I8I8I8", n)
	-- load the key
	local k1, k2, k3, k4 = string.unpack("<I8I8I8I8", k)
	s[5], s[6], s[7], s[8] =  k1, k2, k3, k4
	--
	s[13] = s[13] ~ 64  --W
	s[14] = s[14] ~ 4   --L
	s[15] = s[15] ~ 1   --P
	s[16] = s[16] ~ 256 --T
	--
	permute(s)
	--
	s[13] = s[13] ~ k1
	s[14] = s[14] ~ k2
	s[15] = s[15] ~ k3
	s[16] = s[16] ~ k4
	--
	return s
end

local function absorb_data(s, ins, tag)
	local inlen = #ins
	local i = 1
	if inlen > 0 then
		while inlen >= 96 do
			absorb_block(s, ins, i, tag)
			inlen = inlen - 96
			i = i + 96
		end
		absorb_lastblock(s, ins:sub(i), tag)
	end--if
end

local function encrypt_data(s, out_table, ins)
	local inlen = #ins
	local i = 1
	if inlen > 0 then
		while inlen >= 96 do
			encrypt_block(s, out_table, ins, i)
			inlen = inlen - 96
			i = i + 96
		end
		encrypt_lastblock(s, out_table, ins:sub(i))
	end
end

local function decrypt_data(s, out_table, ins)
	local inlen = #ins
	local i = 1
	if inlen > 0 then
		while inlen >= 96 do
			decrypt_block(s, out_table, ins, i)
			inlen = inlen - 96
			i = i + 96
		end
		decrypt_lastblock(s, out_table, ins:sub(i))
	end
end

local function finalize(s, k)
	-- return the authentication tag (32-byte string)
	--
	s[16] = s[16] ~ FINAL_TAG
	permute(s)
	--
	local k1, k2, k3, k4 = string.unpack("<I8I8I8I8", k)
	--
	s[13] = s[13] ~ k1
	s[14] = s[14] ~ k2
	s[15] = s[15] ~ k3
	s[16] = s[16] ~ k4
	--
	permute(s)
	--
	s[13] = s[13] ~ k1
	s[14] = s[14] ~ k2
	s[15] = s[15] ~ k3
	s[16] = s[16] ~ k4
	--
	local authtag = string.pack("<I8I8I8I8", s[13], s[14], s[15], s[16])
	return authtag
end

local function verify_tag(tag1, tag2)
	return tag1 == tag2
end


--- Encrypts the given plain text using the NORX cipher with an AEAD construction.
--- @param key string - The key used for encryption.
--- @param nonce string - The nonce used for encryption 32-byte string.
--- @param plain string - The plain text to be encrypted 32-byte string.
--- @param header? string (optional) - The header to be encrypted 32-byte string. Defaults to an empty string.
--- @param trailer? string (optional) - The trailer to be encrypted 32-byte string. Defaults to an empty string.
--- @returns table - A table containing the encrypted message in bytes, string, and hex formats.
local function aead_encrypt(key, nonce, plain, header, trailer)
	header = header or ""
	trailer = trailer or ""
	local out_table = {}
	local state = init(key, nonce)
	absorb_data(state, header, HEADER_TAG)
	encrypt_data(state, out_table, plain)
	absorb_data(state, trailer, TRAILER_TAG)
	local tag = finalize(state, key)
	table.insert(out_table, tag)
	local crypted = table.concat(out_table)
	assert(#crypted == #plain + 32)

    local public = {}

    public.asBytes = function()
        return out_table
    end

    public.asString = function()
        return crypted
    end

    public.asHex = function()
        return Hex.stringToHex(crypted)
    end

    return public
end

--- Decrypts the given crypted text using the NORX cipher with an AEAD construction.
--- @param key string - The key used for decryption 32-byte string.
--- @param nonce string - The nonce used for decryption 32-byte string.
--- @param crypted string - The crypted text to be decrypted 32-byte string.
--- @param header? string (optional) - The header to be decrypted 32-byte string. Defaults to an empty string.
--- @param trailer? string (optional) - The trailer to be decrypted 32-byte string. Defaults to an empty string.
--- @returns string|nil - The decrypted plain text, or (nil, error message) if the authenticated decryption fails.
local function aead_decrypt(key, nonce, crypted, header, trailer)
	header = header or ""
	trailer = trailer or ""
	assert(#crypted >= 32)
	local out_table = {}
	local state = init(key, nonce)
	absorb_data(state, header, HEADER_TAG)
	local ctag = crypted:sub(#crypted - 32 + 1)
	local c = crypted:sub(1, #crypted - 32)
	decrypt_data(state, out_table, c)
	absorb_data(state, trailer, TRAILER_TAG)
	local tag = finalize(state, key)
	if not verify_tag(tag, ctag) then return nil, "auth failure" end
	local plain = table.concat(out_table)
	return plain
end

return {
	encrypt = aead_encrypt,
	decrypt = aead_decrypt,
	--
	key_size = 32,
	nonce_size = 32,
	variant = "NORX 64-4-1",
}
