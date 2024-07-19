import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');

const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }
test('run norx cipher successfully', async () => {
	const handle = await AoLoader(wasm, options);
	const env = {
		Process: {
			Id: 'AOS',
			Owner: 'FOOBAR',
			Tags: [{ name: 'Name', value: 'Thomas' }],
		},
	};

	const results = [
		// encrypted cipher
		"0bb35a06938e6541eccd4440adb7b46118535f60b09b4adf378807a53df19fc4ea28",
		// auth tag
		"5a06938e6541eccd4440adb7b46118535f60b09b4adf378807a53df19fc4ea28",
		// decrypted value
		"ao"
	]

	const data = `
		local crypto = require(".crypto");
		local Hex = require(".crypto.util.hex")

		local results = {}

		-- nonce and key are 32 bytes each
		local key = "super_duper_secret_password_shhh"
		local nonce = "00000000000000000000000000000000"

		-- Data to encrypt
		local data = "ao"

		-- Header and trailer are optional
		local header, trailer = data, data

		local encrypted = crypto.cipher.norx.encrypt(key, nonce, data, header, trailer).asString()
		local decrypted = crypto.cipher.norx.decrypt(key, nonce, encrypted, header, trailer)

		local authTag = encrypted:sub(#encrypted-32+1)

		results[1] = Hex.stringToHex(encrypted)
		results[2] = Hex.stringToHex(authTag)
		results[3] = decrypted

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
	assert.ok(true);
});
