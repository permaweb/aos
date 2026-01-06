import { test, mock } from 'node:test'
import assert from 'node:assert'

import { shouldShowSplash, shouldSuppressVersionBanner } from '../src/services/process-type.js'
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

test('version suppressOutput option prevents logging', () => {
  const suppressedLogs = captureLogs(() => version('process-id', { suppressOutput: true }))
  assert.deepStrictEqual(suppressedLogs, [])

  const normalLogs = captureLogs(() => version('process-id', { suppressOutput: false }))
  assert.ok(normalLogs.some(line => /Client Version/i.test(line)))
  assert.ok(normalLogs.some(line => /Type "Ctrl-C" twice/i.test(line)))
  assert.ok(normalLogs.some(line => /Your AOS process:/i.test(line)))
})
