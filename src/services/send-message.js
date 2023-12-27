import { connect, createDataItemSigner } from "@permaweb/ao-sdk"
import { fromPromise } from 'hyper-async'

export function sendMessage({ processId, wallet, tags }) {
  const signer = createDataItemSigner(wallet)
  return fromPromise(() => connect().message({ process: processId, signer, tags }))()
  //.map(result => (console.log(result), result))

}
