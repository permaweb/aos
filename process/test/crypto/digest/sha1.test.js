import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }
test('run sha1 hash successfully', async () => {
	const cases = [
		['', 'da39a3ee5e6b4b0d3255bfef95601890afd80709'],
		['ao', 'c29dd6c83b67a1d6d3b28588a1f068b68689aa1d'],
		['abc', 'a9993e364706816aba3e25717850c26c9cd0d89d'],
		['abcdefghijklmnopqrstuvwxyz', '32d10c7b8cf96570ca04ce37f2a19d84240d3a89'],
		[
			'Hello World!',
			'2ef7bde608ce5404e97d5f042f95f89f1c232871',
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
			return crypto.digest.sha1(str).asHex();
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
