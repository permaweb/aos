import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');

const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }
test('run morus cipher successfully', async () => {
	const handle = await AoLoader(wasm, options);
	const env = {
		Process: {
			Id: 'AOS',
			Owner: 'FOOBAR',
			Tags: [{ name: 'Name', value: 'Thomas' }],
		},
	};

	const results = ['514ed31473d8fb0b76c6cbb17af35ed01d0a', 'ao', '6164646974696f6e616c20646174616aae7a8b95c50047bea251c3b7133eec5fcc', 'ao']


	const data = `
		local crypto = require(".crypto");

		local results = {};

		local m = "ao";

		--[[
			16 bit key
		]]--

		local k = "super_secret_shh"
		local iv = "0000000000000000"
		local ad= "";

		local e = crypto.cipher.morus.encrypt(k, iv, m, ad);
		results[1] = e.asHex();
		results[2] = crypto.cipher.morus.decrypt(k, iv, e.asString(), #ad);

		--[[
			32 bit key
		]]--
		k = crypto.utils.hex.hexToString("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f");
		ad = "additional data";
		
		e = crypto.cipher.morus.encrypt(k, iv, m, ad);
		results[3] = e.asHex();
		results[4] = crypto.cipher.morus.decrypt(k, iv, e.asString(), #ad);

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
