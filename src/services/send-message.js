import { connect, createDataItemSigner } from "@permaweb/ao-sdk"
import { fromPromise } from 'hyper-async'

export function sendMessage({ processId, wallet, tags, data }) {
  const signer = createDataItemSigner(wallet)
  return fromPromise(() => connect().message({ process: processId, signer, tags, data }))()
  //.map(result => (console.log(result), result))

}
