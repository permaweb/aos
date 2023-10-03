import test from 'node:test'
import assert from 'assert'
import Arweave from 'arweave'

const arweave = Arweave.init({})

test('get wallet address', async () => {
  const jwk = await arweave.wallets.generate()
  const { address } = await import('./address.js')
  const result = await address(jwk).toPromise()
  console.log(result)
  assert.ok(true)
})