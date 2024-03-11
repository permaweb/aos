import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');

test('run morus cipher successfully', async () => {
	const handle = await AoLoader(wasm);
	const env = {
		Process: {
			Id: 'AOS',
			Owner: 'FOOBAR',
			Tags: [{ name: 'Name', value: 'Thomas' }],
		},
	};

	const results = [ 'da4f100a110da5c37e0c91e1609846377540', 'ao' ,'6164646974696f6e616c2064617461145d484fb6261fca15a66193de4ae1a06886','ao']

	
	const data = `
		local crypto = require(".crypto");

		local results = {};

		local m = "ao";

		--[[
			16 bit key
		]]--

		local k = crypto.utils.hex.hexToString("00000000000000000000000000000000");
		local iv = crypto.utils.hex.hexToString("00000000000000000000000000000000");
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
