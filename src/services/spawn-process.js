import { fromPromise } from 'hyper-async'
import { connect, createDataItemSigner } from '@permaweb/aoconnect'


const SCHEDULER = "T9UhH6kyesadPlAkH-4WT8znbmz_b6Nnlvu1vDtZGB4"
//const SCHEDULER = "TZ7o7SIZ06ZEJ14lXwVtng1EtSx60QkPy-kh-kdAXog"

export function spawnProcess({ wallet, src, tags }) {
  const signer = createDataItemSigner(wallet)
  const info = {}
  if (process.env.CU_URL) {
    info['CU_URL'] = process.env.CU_URL
  }
  if (process.env.MU_URL) {
    info['MU_URL'] = process.env.MU_URL
  }
  return fromPromise(() => connect(info).spawn({
    module: src, scheduler: SCHEDULER, signer, tags
  })
    .then(result => new Promise((resolve) => setTimeout(() => resolve(result), 1000)))
  )()

}