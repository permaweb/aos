import { connect, createDataItemSigner } from "@permaweb/ao-sdk"
import { fromPromise } from 'hyper-async'

export function sendMessage({ processId, wallet, tags }) {
  const signer = createDataItemSigner(wallet)
  return fromPromise(() => connect().sendMessage(
    { processId, signer, tags, anchor: null }))()
  //.map(result => (console.log(result), result))

}
