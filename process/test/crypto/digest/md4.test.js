import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');

test('run md4 hash successfully', async () => {
	const cases = [
		['', '31d6cfe0d16ae931b73c59d7e0c089c0'],
		['ao','e068dfe3d8cb95311b58be566db66954'],
		['abc', 'a448017aaf21d8525fc10ae87aa6729d'],
		['abcdefghijklmnopqrstuvwxyz', 'd79e1c308aa5bbcdeea8ed63df412da9'],
		[
			'Hello World!',
			'b2a5cc34fc21a764ae2fad94d56fadf6',
		],
	];
	const handle = await AoLoader(wasm);
	const env = {
		Process: {
			Id: 'AOS',
			Owner: 'FOOBAR',
			Tags: [{ name: 'Name', value: 'Thomas' }],
		},
	};

	cases.forEach(async (e) => {
		const data = `
			local crypto = require(".crypto");

			local str = crypto.utils.stream.fromString("${e[0]}");
			return crypto.digest.md4(str).asHex();
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
		assert.equal(result.Output?.data.output, e[1]);
		assert.ok(true);
	});
});
