import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }
test('run hmac successfully', async () => {
	const handle = await AoLoader(wasm, options);
	const env = {
		Process: {
			Id: 'AOS',
			Owner: 'FOOBAR',
			Tags: [{ name: 'Name', value: 'Thomas' }],
		},
	};

	const results = ["3966f45acb53f7a1a493bae15afecb1a204fa32d", "542da02a324155d688c7689669ff94c6a5f906892aa8eccd7284f210ac66e2a7"]

	const data = `
		local crypto = require(".crypto")

		local data = crypto.utils.stream.fromString("ao")
		local key = crypto.utils.array.fromString("super_secret_key")

		local results = {}

		results[1] = crypto.mac.createHmac(data, key).asHex()
		results[2] = crypto.mac.createHmac(data, key, "sha256").asHex()

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
