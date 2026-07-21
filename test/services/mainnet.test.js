import { after, before, test } from 'node:test'
import assert from 'node:assert'

import {
  createMainnetMessageArgs,
  createMainnetSpawnArgs
} from '../../src/services/mainnet.js'

const originalExecutionDevice = process.env.AOS_EXECUTION_DEVICE

before(() => {
  delete process.env.AOS_EXECUTION_DEVICE
})

after(() => {
  if (originalExecutionDevice === undefined) delete process.env.AOS_EXECUTION_DEVICE
  else process.env.AOS_EXECUTION_DEVICE = originalExecutionDevice
})

test('mainnet spawn and message default to the Lua execution device', () => {
  const spawn = createMainnetSpawnArgs({
    tags: [],
    authority: 'authority',
    src: 'lua-module',
    data: ''
  })
  const message = createMainnetMessageArgs({
    processId: 'process-id',
    tags: [],
    data: 'return 1'
  })

  assert.strictEqual(spawn.executionDevice, 'lua@5.3')
  assert.strictEqual(spawn.module, 'lua-module')
  assert.strictEqual(message.executionDevice, 'lua@5.3')
})

test('mainnet spawn accepts the genesis WASM execution device', () => {
  const spawn = createMainnetSpawnArgs({
    tags: [],
    authority: 'authority',
    src: 'wasm-module',
    data: '',
    executionDevice: 'genesis-wasm'
  })

  assert.strictEqual(spawn.executionDevice, 'genesis-wasm')
  assert.strictEqual(spawn.module, 'wasm-module')
})
