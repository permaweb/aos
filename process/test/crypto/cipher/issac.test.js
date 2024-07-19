import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }
test('run issac cipher successfully', async () => {
	const handle = await AoLoader(wasm, options);
	const env = {
		Process: {
			Id: 'AOS',
			Owner: 'FOOBAR',
			Tags: [{ name: 'Name', value: 'Thomas' }],
		},
	};

	const results = ["7851", "ao"]

	const data = `
		local crypto = require(".crypto");

		local results = {};

		local message = "ao";
		local key = "secret_key";

		local encrypted, decrypted;

		encrypted = crypto.cipher.issac.encrypt(message, key);
		decrypted = crypto.cipher.issac.decrypt(encrypted.asString(), key);

		results[1] = encrypted.asHex();
		results[2] = decrypted;

		return table.concat(results, ", ");
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
