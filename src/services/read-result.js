import { connect } from "@permaweb/aoconnect"
import { fromPromise } from 'hyper-async'

export function readResult(params) {
  const info = {}
  if (process.env.CU_URL) {
    info['CU_URL'] = process.env.CU_URL
  }
  return fromPromise(() => connect(info).result(params))()
  //.map(result => (console.log(result), result))

}
