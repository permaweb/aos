import { connect } from "@permaweb/ao-sdk"
import { fromPromise } from 'hyper-async'

export function readResult(id) {
  return fromPromise(() => connect().result({ message: id }))()
    .map(result => (console.log(result), result))

}
