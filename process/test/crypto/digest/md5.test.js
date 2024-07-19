import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }

test('run md5 hash successfully', async () => {
	const cases = [
		['', 'd41d8cd98f00b204e9800998ecf8427e'],
		['ao', 'adac5e63f80f8629e9573527b25891d3'],
		['abc', '900150983cd24fb0d6963f7d28e17f72'],
		['abcdefghijklmnopqrstuvwxyz', 'c3fcd3d76192e4007dfb496cca67e13b'],
		[
			'Hello World!',
			'ed076287532e86365e841e92bfc50d8c',
		],
	];
	const handle = await AoLoader(wasm, options);
	const env = {
		Process: {
			Id: 'AOS',
			Owner: 'FOOBAR',
			Tags: [{ name: 'Name', value: 'Thomas' }],
		},
	};

	const testCase = async (e) => {
		const data = `
			local crypto = require(".crypto");

			local str = crypto.utils.stream.fromString("${e[0]}");
			return crypto.digest.md5(str).asHex();
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
		assert.equal(result.Output?.data, e[1]);
		assert.ok(true);
	};
	await testCase(cases[0]);
	await testCase(cases[1]);
	await testCase(cases[2]);
	await testCase(cases[3]);
	await testCase(cases[4]);
});
