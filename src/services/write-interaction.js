import * as sdk from "@permaweb/ao-sdk"
import { fromPromise } from 'hyper-async'

export function writeInteraction({ contract, input, wallet, tags }) {
  const signer = sdk.createDataItemSigner(wallet)
  return fromPromise(() => sdk.writeInteraction(contract, input, signer, tags = []))()
  //.map(result => (console.log(result), result))

}
