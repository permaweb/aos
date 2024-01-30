import { connect, createDataItemSigner } from "@permaweb/aoconnect"
import { fromPromise } from 'hyper-async'

export function sendMessage({ processId, wallet, tags, data }) {
  const signer = createDataItemSigner(wallet)
  const info = {}
  if (process.env.CU_URL) {
    info['CU_URL'] = process.env.CU_URL || 'https://cu.ao-testnet.xyz'
  }
  if (process.env.MU_URL) {
    info['MU_URL'] = process.env.MU_URL || 'https://mu.ao-testnet.xyz'
  }
  return fromPromise(() => connect(info).message({ process: processId, signer, tags, data }))()
  //.map(result => (console.log(result), result))

}
