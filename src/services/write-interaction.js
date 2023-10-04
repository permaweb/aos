import { writeInteraction, createDataItemSigner } from "@permaweb/ao-sdk"
import { fromPromise } from 'hyper-async'

export function writeInteraction({ contract, input, wallet, tags }) {
  const signer = createDataItemSigner(wallet)
  return fromPromise(() => writeInteraction(contract, input, signer, tags = []))()
    .map(result => (console.log(result), result))

}
