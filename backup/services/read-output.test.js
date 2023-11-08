import test from 'node:test'
import assert from 'assert/strict'

test('read output', async () => {
  const { readOutput } = await import('./read-output.js')
  const contract = 'K7GRBWNQ12dyAQ41XNmMxnygOlHtfIKNeIICmfKQvTg'
  const result = await readOutput(contract).toPromise()
  console.log(result)
  assert.ok(true)
})