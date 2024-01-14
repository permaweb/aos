import { connect } from "@permaweb/aoconnect"
import { fromPromise } from 'hyper-async'

export function readResult(params) {
  return fromPromise(() => connect().result(params))()
  //.map(result => (console.log(result), result))

}
