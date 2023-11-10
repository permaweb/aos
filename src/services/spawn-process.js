import { fromPromise } from 'hyper-async'
import { connect, createDataItemSigner } from '@permaweb/ao-sdk'


export function spawnProcess({ wallet, src, tags }) {
  const signer = createDataItemSigner(wallet)

  return fromPromise(() => connect().spawnProcess({
    srcId: src, signer, tags
  }))()

}