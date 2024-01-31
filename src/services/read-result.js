import { connect } from "@permaweb/aoconnect"
import { fromPromise, Resolved, Rejected } from 'hyper-async'

export function readResult(params) {
  const info = {}
  if (process.env.CU_URL) {
    info['CU_URL'] = process.env.CU_URL || 'https://cu.ao-testnet.xyz'
  }
  if (process.env.MU_URL) {
    info['MU_URL'] = process.env.MU_URL || 'https://mu.ao-testnet.xyz'
  }
  return fromPromise(() =>
    new Promise((resolve) => setTimeout(() => resolve(params), 100))
  )().chain(fromPromise(() => connect(info).result(params)))
    // log the error messages most seem related to 503
    //.bimap(_ => (console.log(_), _), _ => (console.log(_), _))
    .bichain(fromPromise(() =>
      new Promise((resolve, reject) => setTimeout(() => reject(params), 50))
    ),
      Resolved
    )
}
