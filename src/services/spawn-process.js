import { fromPromise } from 'hyper-async'
import { connect, createDataItemSigner } from '@permaweb/aoconnect'

// vm const SCHEDULER = "T9UhH6kyesadPlAkH-4WT8znbmz_b6Nnlvu1vDtZGB4"
// dev const SCHEDULER = "TZ7o7SIZ06ZEJ14lXwVtng1EtSx60QkPy-kh-kdAXog"

export function spawnProcess({ wallet, src, tags }) {
  const SCHEDULER = process.env.SCHEDULER || "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA"
  const signer = createDataItemSigner(wallet)
  const info = {}
  if (process.env.CU_URL) {
    info['CU_URL'] = process.env.CU_URL || 'https://cu.ao-testnet.xyz'
  }
  if (process.env.MU_URL) {
    info['MU_URL'] = process.env.MU_URL || 'https://mu.ao-testnet.xyz'
  }
  return fromPromise(() => connect(info).spawn({
    module: src, scheduler: SCHEDULER, signer, tags
  })
    .then(result => new Promise((resolve) => setTimeout(() => resolve(result), 500)))
  )()

}