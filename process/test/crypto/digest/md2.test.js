import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');

test('run md2 hash successfully', async () => {
	const cases = [
		['', '8350e5a3e24c153df2275c9f80692773'],
		['ao','0d4e80edd07bee6c7965b21b25a9b1ea'],
		['abc', 'da853b0d3f88d99b30283a69e6ded6bb'],
		['abcdefghijklmnopqrstuvwxyz', '4e8ddff3650292ab5a4108c3aa47940b'],
		[
			'Hello World!',
			'315f7c67223f01fb7cab4b95100e872e',
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
			return crypto.digest.md2(str).asHex();
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
