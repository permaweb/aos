import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');

test('run hmac successfully', async () => {
	const handle = await AoLoader(wasm);
	const env = {
		Process: {
			Id: 'AOS',
			Owner: 'FOOBAR',
			Tags: [{ name: 'Name', value: 'Thomas' }],
		},
	};

	const results = [ "81ed1cb2e8969a74d74e22891d5ba2f85134d1a5", "1b3a581fd7fd5784861392fdbb031e5d74a27af8b5c0221a57f3ebb364b941a7" ]
	
	const data = `
		local crypto = require(".crypto")

		local Stream = require(".crypto.util.stream")
		local Array = require(".crypto.util.array")

		local data = Stream.fromString("ao")
		local key = Array.fromString("Jefebbadadada")

		local results = {}

		results[1] = crypto.mac.createHmac(data, key).asHex()
		results[2] = crypto.mac.createHmac(data, key, "sha256").asHex()

		return table.concat(results, ", ")
	`;
	const msg = {
		Target: 'AOS',
		Owner: 'FOOBAR',
		['Block-Height']: '1000',
		Id: '1234xyxfoo',
		Module: 'WOOPAWOOPA',
		Tags: [{ name: 'Action', value: 'Eval' }],
		Data: data,
	};

	const result = await handle(null, msg, env);
	assert.equal(result.Output?.data.output, results.join(', '));
	assert.ok(true);
});
