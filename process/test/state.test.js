import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: 'wasm64-unknown-emscripten-draft_2024_02_15' }

const env = {
  Process: {
    Id: 'AOS',
    Owner: 'FOOBAR',
    Tags: [{ name: 'Name', value: 'Thomas' }]
  }
}

async function init(handle) {
  const { Memory } = await handle(
    null,
    {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '999',
      Id: 'AOS',
      Module: 'WOOPAWOOPA',
      Tags: [{ name: 'Name', value: 'Thomas' }]
    },
    env
  )
  return Memory
}

const envWithAuthorities = {
  Process: {
    Id: 'AOS',
    Owner: 'FOOBAR',
    Tags: [
      { name: 'Name', value: 'Thomas' },
      { name: 'Authority', value: 'FOO,BAR,FOOBAR,UNIQUE-ADDRESS' }
    ]
  }
}

async function initWithAuthorities(handle) {
  const { Memory } = await handle(
    null,
    {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '999',
      Id: 'AOS',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Name', value: 'Thomas' },
        { name: 'Authority', value: 'FOO,BAR,FOOBAR,UNIQUE-ADDRESS' }
      ]
    },
    envWithAuthorities
  )
  return Memory
}

test('check state properties for aos', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)

  const msg = {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',
    From: 'FOOBAR',
    ['Block-Height']: '1000',
    Id: '1234xyxfoo',
    Module: 'WOOPAWOOPA',
    Tags: [{ name: 'Action', value: 'Eval' }],
    Data: 'print("name: " .. Name .. ", owner: " .. Owner)'
  }
  const result = await handle(start, msg, env)

  assert.equal(result.Output?.data, 'name: Thomas, owner: FOOBAR')
  assert.ok(true)
})

test('test authorities', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)

  const msg = {
    Target: 'AOS',
    Owner: 'BEEP',
    From: 'BAM',
    ['Block-Height']: '1000',
    Id: '1234xyxfoo',
    Module: 'WOOPAWOOPA',
    Tags: [{ name: 'Action', value: 'Eval' }],
    Data: '1 + 1'
  }
  const result = await handle(start, msg, env)
  assert.ok(result.Output.data.includes('Message is not trusted! From: BAM - Owner: BEEP'))
})

test('test multiple process tag authorities', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await initWithAuthorities(handle)

  // Should be trusted (FOOBAR is in the authority list)
  const msg0 = {
    Target: 'AOS',
    Owner: 'FOOBAR',
    From: 'FOOBAR',
    ['Block-Height']: '1000',
    Id: '1234xyxfoo1',
    Module: 'WOOPAWOOPA',
    Tags: [{ name: 'Action', value: 'Eval' }],
    Data: 'ao.authorities'
  }
  const result0 = await handle(start, msg0, envWithAuthorities)
  assert.ok(result0.Output.data.includes('FOO'))
  assert.ok(result0.Output.data.includes('BAR'))
  assert.ok(result0.Output.data.includes('FOOBAR'))
  assert.ok(result0.Output.data.includes('UNIQUE-ADDRESS'))

  // Should be trusted (FOOBAR is in the authority list)
  const msg1 = {
    Target: 'AOS',
    Owner: 'FOOBAR',
    From: 'FOOBAR',
    ['Block-Height']: '1000',
    Id: '1234xyxfoo1',
    Module: 'WOOPAWOOPA',
    Tags: [{ name: 'Action', value: 'Eval' }],
    Data: '#ao.authorities'
  }
  const result1 = await handle(start, msg1, envWithAuthorities)
  assert.ok(result1.Output.data == '4')
  // Should be trusted (FOO is in the authority list)
  const msg2 = {
    Target: 'AOS',
    Owner: 'FOO',
    From: 'FOO',
    ['Block-Height']: '1000',
    Id: '1234xyxfoo2',
    Module: 'WOOPAWOOPA',
    Tags: [{ name: 'Action', value: 'Testing' }],
    Data: 'Hello world!'
  }
  const result2 = await handle(start, msg2, envWithAuthorities)
  assert.ok(result2.Output.data.includes('New Message From'))

  // Should reject (BAM1, BAM2 are not in the authority list)
  const msg3 = {
    Target: 'AOS',
    Owner: 'BAM1',
    From: 'BAM2',
    ['Block-Height']: '1000',
    Id: '1234xyxfoo3',
    Module: 'WOOPAWOOPA',
    Tags: [{ name: 'Action', value: 'Testing' }],
    Data: 'Hello world!'
  }
  const result3 = await handle(start, msg3, envWithAuthorities)
  assert.ok(result3.Output.data.includes('Message is not trusted! From: BAM2 - Owner: BAM1'))

  // Should accept (FOO, UNIQUE-ADDRESS are in the authority list)
  const msg4 = {
    Target: 'AOS',
    Owner: 'FOO',
    From: 'UNIQUE-ADDRESS',
    ['Block-Height']: '1000',
    Id: '1234xyxfoo4',
    Module: 'WOOPAWOOPA',
    Tags: [{ name: 'Action', value: 'Testing' }],
    Data: 'Hello world!'
  }
  const result4 = await handle(start, msg4, envWithAuthorities)
  assert.ok(result4.Output.data.includes('New Message From'))
})

test('test utils', async () => {
  const handle = await AoLoader(wasm, options)
  const start = await init(handle)

  const msg = {
    Target: 'AOS',
    Owner: 'FOOBAR',
    From: 'FOOBAR',
    ['Block-Height']: '1000',
    Id: '1234xyxfoo',
    Module: 'WOOPAWOOPA',
    Tags: [{ name: 'Action', value: 'Eval' }],
    Data: `
return require('.utils').capitalize("foo-bar")
    `
  }
  const result = await handle(start, msg, env)
  assert.ok(result.Output.data.includes('Foo-bar'))
})
