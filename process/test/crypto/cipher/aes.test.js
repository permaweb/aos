import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15", computeLimit: 10024704733 }

test('run aes cipher successfully', async () => {
	const handle = await AoLoader(wasm, options);
	const env = {
		Process: {
			Id: 'AOS',
			Owner: 'FOOBAR',
			Tags: [{ name: 'Name', value: 'Thomas' }],
		},
	};

	const results = [
		// AES128 CBC Mode
		"A3B9E6E1FBD9D46930E5F76807C84B8E", "616F0000000000000000000000000000",
		// AES128 ECB Mode
		"3FF54BD61AD1AA06BC367A10575CC7C5", "616F0000000000000000000000000000",
		// AES128 CFB Mode
		"1DA7169C093D6B23160B6785B28E4BED", "616F0000000000000000000000000000",
		// AES128 OFB Mode
		"1DA7169C093D6B23160B6785B28E4BED", "616F0000000000000000000000000000",
		// AES128 CTR Mode
		"1DA7169C093D6B23160B6785B28E4BED", "616F0000000000000000000000000000"
	]

	const data = `
		local crypto = require(".crypto")
		local Hex = require(".crypto.util.hex")

		local modes = { "CBC", "ECB", "CFB", "OFB", "CTR" }
		local iv = "super_secret_shh"

		local key_128 = "super_secret_shh"
		local key_192 = "super_secret_password_sh"
		local key_256 = "super_duper_secret_password_shhh"
		local results = {}

		local run = function(keySize, modes)
			for _, mode in ipairs(modes) do
				local key = key_128
				if keySize == 192 then
					key = key_192
				elseif keySize == 256 then
					key = key_256
				end

				
				local l_iv = iv
				if mode == "ECB" then
					l_iv = ""
				end

				local encrypted = crypto.cipher.aes.encrypt("ao", key, l_iv, mode, keySize).asHex()
				local decrypted = crypto.cipher.aes.decrypt(encrypted, key, l_iv, mode, keySize).asHex()
				results[#results + 1] = encrypted
				results[#results + 1] = decrypted
			end
		end

		run(128, modes)
		-- run(192, modes)
		-- run(256, modes)
		return table.concat(results, ", ")
	`;
	const msg = {
		Target: 'AOS',
		From: 'FOOBAR',
		Owner: 'FOOBAR',
		['Block-Height']: '1000',
		Id: '1234xyxfoo',
		Module: 'WOOPAWOOPA',
		Tags: [{ name: 'Action', value: 'Eval' }],
		Data: data,
	};

	const result = await handle(null, msg, env);

	assert.equal(result.Output?.data, results.join(', '));
	// assert.ok(result.GasUsed >= 3000000000)
	assert.ok(true);
});
