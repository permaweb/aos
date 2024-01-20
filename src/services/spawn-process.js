import { fromPromise } from 'hyper-async'
import { connect, createDataItemSigner } from '@permaweb/aoconnect'


export function spawnProcess({ wallet, src, tags }) {
  const signer = createDataItemSigner(wallet)
  const info = {}
  if (process.env.CU_URL) {
    info['CU_URL'] = process.env.CU_URL
  }
  return fromPromise(() => connect(info).spawn({
    module: src, scheduler: 'TZ7o7SIZ06ZEJ14lXwVtng1EtSx60QkPy-kh-kdAXog', signer, tags
  })
    .then(result => new Promise((resolve) => setTimeout(() => resolve(result), 1000)))
  )()

}