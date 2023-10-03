import test from 'node:test'
import assert from 'assert'

import { fromPromise } from 'hyper-async'

const gql = () => fromPromise(() => Promise.resolve({ data: { transactions: { edges: [] } } }))()
const address = () => fromPromise(() => Promise.resolve('vh-NTHVvlKZqRxc8LyyTNok65yQ55a_PJ1zWLb9G2JI'))()

test('register aos', async () => {
  const { register } = await import('./register.js')
  const args = { w: './wallet.json' }
  const services = { gql, address }
  const result = await register(args, services).toPromise()
  console.log(result)
  assert.ok(true)
})