import { test, mock } from 'node:test'
import assert from 'node:assert'

import {
  defaultModuleForExecutionDevice,
  resolveExecutionDeviceFromFlags,
  shouldShowSplash,
  shouldSuppressVersionBanner
} from '../src/services/process-type.js'
import { version } from '../src/services/version.js'

const runArgs = { run: 'print("hi")' }
const hyperArgs = { hyper: true }
const defaultArgs = { _: ['default'] }

mock.method(process, 'exit', () => {})

const captureLogs = fn => {
  const logs = []
  const originalLog = console.log
  console.log = (...args) => logs.push(args.join(' '))
  try {
    fn()
  } finally {
    console.log = originalLog
  }
  return logs
}

test('shouldShowSplash returns true when --run absent', () => {
  assert.strictEqual(shouldShowSplash(defaultArgs), true)
  assert.strictEqual(shouldSuppressVersionBanner(defaultArgs), false)
})

test('shouldShowSplash returns false when --run present', () => {
  assert.strictEqual(shouldShowSplash(runArgs), false)
  assert.strictEqual(shouldSuppressVersionBanner(runArgs), true)
})

test('shouldShowSplash returns true when only --hyper present', () => {
  assert.strictEqual(shouldShowSplash(hyperArgs), true)
  assert.strictEqual(shouldSuppressVersionBanner(hyperArgs), false)
})

test('Lua is the default HyperBEAM execution device', () => {
  assert.strictEqual(resolveExecutionDeviceFromFlags({}), 'lua@5.3')
  assert.strictEqual(resolveExecutionDeviceFromFlags({ 'execution-device': 'lua@5.3' }), 'lua@5.3')
})

test('genesis WASM can be selected explicitly and is implied by sqlite', () => {
  assert.strictEqual(
    resolveExecutionDeviceFromFlags({ 'execution-device': 'genesis-wasm' }),
    'genesis-wasm'
  )
  assert.strictEqual(resolveExecutionDeviceFromFlags({ sqlite: true }), 'genesis-wasm')
})

test('execution device flags are validated', () => {
  assert.throws(
    () => resolveExecutionDeviceFromFlags({ 'execution-device': 'invalid' }),
    /Expected "lua@5.3" or "genesis-wasm"/
  )
  assert.throws(
    () => resolveExecutionDeviceFromFlags({ sqlite: true, 'execution-device': 'lua@5.3' }),
    /--sqlite flag requires --execution-device genesis-wasm/
  )
})

test('default module follows the selected execution device', () => {
  const pkg = {
    aos: { module: 'wasm-module' },
    hyper: { module: 'lua-module' }
  }

  assert.strictEqual(defaultModuleForExecutionDevice(pkg, 'lua@5.3'), 'lua-module')
  assert.strictEqual(defaultModuleForExecutionDevice(pkg, 'genesis-wasm'), 'wasm-module')
  assert.strictEqual(defaultModuleForExecutionDevice(pkg), 'wasm-module')
})

test('version suppressOutput option prevents logging', () => {
  const suppressedLogs = captureLogs(() => version('process-id', { suppressOutput: true }))
  assert.deepStrictEqual(suppressedLogs, [])

  const normalLogs = captureLogs(() => version('process-id', { suppressOutput: false }))
  assert.ok(normalLogs.some(line => /Client Version/i.test(line)))
  assert.ok(normalLogs.some(line => /Type "Ctrl-C" twice/i.test(line)))
  assert.ok(normalLogs.some(line => /Your AOS process:/i.test(line)))
})
