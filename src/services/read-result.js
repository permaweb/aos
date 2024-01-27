import { connect } from "@permaweb/aoconnect"
import { fromPromise, Resolved, Rejected } from 'hyper-async'

export function readResult(params) {
  const info = {}
  if (process.env.CU_URL) {
    info['CU_URL'] = process.env.CU_URL
  }
  return fromPromise(() => connect(info).result(params))()
    // log the error messages most seem related to 503
    //.bimap(_ => (console.log(_), _), _ => (console.log(_), _))
    .bichain(fromPromise(() =>
      new Promise((resolve, reject) => setTimeout(() => reject(params), 1000))
    ),
      Resolved
    )
}
