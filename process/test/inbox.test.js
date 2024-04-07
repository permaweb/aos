import { test } from 'node:test'
import * as assert from 'node:assert'
import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: "wasm32-unknown-emscripten", computeLimit: 9e22 }
test.skip('inbox unbounded', async () => {
  const handle = await AoLoader(wasm, options)
  const env = {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',
      Tags: [
        { name: 'Name', value: 'Thomas' }
      ]
    }
  }
  const msg = {
    Target: 'AOS',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Data: 'Hello',
    Tags: []
  }
  const result = await handle(null, msg, env)
  let memory = result.Memory
  for (var i = 0; i < 10001; i++) {
    const { Memory } = await handle(memory, msg, env)
    memory = Memory
  }
  const count = await handle(memory, {
    Target: 'AOS',
    Owner: 'FOOBAR',
    ['Block-Height']: "1000",
    Id: "1234xyxfoo",
    Module: "WOOPAWOOPA",
    Tags: [{ name: 'Action', value: 'Eval' }],
    Data: '#Inbox'
  }, env)
  //assert.equal(count.Error, 'Error')
  assert.equal(count.Output?.data?.output, "10000")
  assert.ok(true)
})

