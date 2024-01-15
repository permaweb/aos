import { connect, createDataItemSigner } from "@permaweb/aoconnect"
import { fromPromise } from 'hyper-async'

export function unmonitorProcess({ id, wallet }) {
  const signer = createDataItemSigner(wallet)
  return fromPromise(() => connect().unmonitor({ process: id, signer }))()
  //.map(result => (console.log(result), result))

}
