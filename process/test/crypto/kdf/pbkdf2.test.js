import { test } from 'node:test';
import * as assert from 'node:assert';
import AoLoader from '@permaweb/ao-loader';
import fs from 'fs';

const wasm = fs.readFileSync('./process.wasm');
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" }

test('run pbkdf2 successfully', async () => {
	const results = [
		'C4C21BF2BBF61541408EC2A49C89B9C6',
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

	local salt = crypto.utils.array.fromString("salt")
    local password = crypto.utils.array.fromString("password")
    local iterations = 4
    local keyLen = 16

    local out = crypto.kdf.pbkdf2(password, salt, iterations, keyLen)

	return out.asHex()
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
	assert.equal(result.Output?.data, results);
	assert.ok(true);
});
