import { fromPromise } from 'hyper-async'
import { connect, createDataItemSigner } from '@permaweb/ao-sdk'


export function spawnProcess({ wallet, src, tags }) {
  const signer = createDataItemSigner(wallet)

  return fromPromise(() => connect().spawn({
    module: src, scheduler: 'TZ7o7SIZ06ZEJ14lXwVtng1EtSx60QkPy-kh-kdAXog', signer, tags
  }))()

}