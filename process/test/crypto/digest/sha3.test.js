import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }
test('run sha3 hash successfully', async () => {
	const results = [
		'1bbe785577db997a394d5b4555eec9159cb51f235aec07514872d2d436c6e985',
		'0c29f053400cb1764ce2ec555f598f497e6fcd1d304ce0125faa03bb724f63f213538f41103072ff62ddee701b52c73e621ed4d2254a3e5e9a803d83435b704d',
		'76da52eec05b749b99d6e62bb52333c1569fe75284e6c82f3de12a4618be00d6',
		'046fbfad009a12cef9ff00c2aac361d004347b2991c1fa80fba5582251b8e0be8def0283f45f020d4b04ff03ead9f6e7c43cc3920810c05b33b4873b99affdea'
	];

	const handle = await AoLoader(wasm, options);
	const env = {
		Process: {
			Id: 'AOS',
			Owner: 'FOOBAR',
			Tags: [{ name: 'Name', value: 'Thomas' }],
		},
	};


	const data = `
		local crypto = require(".crypto");

		local results = {};

		results[1] = crypto.digest.sha3_256("ao").asHex();
		results[2] = crypto.digest.sha3_512("ao").asHex();
		results[3] = crypto.digest.keccak256("ao").asHex();
		results[4] = crypto.digest.keccak512("ao").asHex();

		return table.concat(results,", ")
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
