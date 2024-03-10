import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');

test('run sha256 hash successfully', async () => {
	const cases = [
		['', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'],
		['ao','2dd411308b37266d33c9246821adc5aa4002f0091f5e2aece1953789930ad924'],
		['abc', 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'],
		['abcdefghijklmnopqrstuvwxyz', '71c480df93d6ae2f1efad1447c66c9525e316218cf51fc8d9ed832f2daf18b73'],
		[
			'Hello World!',
			'7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
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
			return crypto.digest.sha2_256(str).asHex();
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
