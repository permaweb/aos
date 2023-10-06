import { fromPromise } from 'hyper-async'
import Bundlr from '@bundlr-network/client'

const SU = 'https://gw.warp.cc'

export function createContract({ wallet, src, initState, tags }) {
  // const signer = sdk.createDataItemSigner(wallet)
  // return fromPromise(() => sdk.createContract(src, initState, signer, tags))()
  const bundlr = new Bundlr('https://node2.bundlr.network', 'arweave', wallet)
  tags = [
    { name: 'Content-Type', value: 'text/plain' },
    { name: 'App-Name', value: 'SmartWeaveContract' },
    { name: 'App-Version', value: '0.3.0' },
    { name: 'Contract-Src', value: src },
    { name: 'Init-State', value: JSON.stringify(initState) },
    ...tags
  ]

  return fromPromise(() =>
    bundlr.upload('AOS', { tags })
      .then(result => fetch(SU + '/gateway/contracts/register', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json'
        },
        body: JSON.stringify({
          id: result.id,
          bundlrNode: 'node2'
        })
      })
        .then(res => res.json())
        .then(_ => result.id)
      )

  )()
}