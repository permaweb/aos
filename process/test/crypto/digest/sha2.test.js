import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');

test('run sha2 hash successfully', async () => {
	const results = [
		'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
		'2dd411308b37266d33c9246821adc5aa4002f0091f5e2aece1953789930ad924',
		'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f',
		'6f36a696b17ce5a71efa700e8a7e47994f3e134a5e5f387b3e7c2c912abe94f94ee823f9b9dcae59af99e2e34c8b4fb0bd592260c6720ee49e5deaac2065c4b1'
	];
	const handle = await AoLoader(wasm);
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
	
	results[1] = crypto.digest.sha2_256("abc");
	results[2] = crypto.digest.sha2_256("ao");
	
	results[3] = crypto.digest.sha2_512("abc");
	results[4] = crypto.digest.sha2_512("ao");

	return table.concat(results,", ")
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
