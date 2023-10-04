import * as sdk from "@permaweb/ao-sdk"
import { fromPromise } from 'hyper-async'

export function createContract({ wallet, src, initState, tags }) {
  const signer = sdk.createDataItemSigner(wallet)
  return fromPromise(() => sdk.createContract(src, initState, signer, tags))()


}