import * as sdk from '@permaweb/ao-sdk'
import { fromPromise } from 'hyper-async'

export function readOutput(contractId) {
  return fromPromise(() => sdk.readState(contractId))()
}