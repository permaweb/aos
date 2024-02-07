import { connect, createDataItemSigner } from "@permaweb/aoconnect"
import { fromPromise, Resolved, Rejected } from 'hyper-async'
import chalk from 'chalk'
import { getPkg } from './get-pkg.js'

const pkg = getPkg()
const info = {
  CU_URL: process.env.CU_URL,
  MU_URL: process.env.MU_URL
}

export function readResult(params) {

  return fromPromise(() =>
    new Promise((resolve) => setTimeout(() => resolve(params), 500))
  )().chain(fromPromise(() => connect(info).result(params)))
    // log the error messages most seem related to 503
    //.bimap(_ => (console.log(_), _), _ => (console.log(_), _))
    .bichain(fromPromise(() =>
      new Promise((resolve, reject) => setTimeout(() => reject(params), 500))
    ),
      Resolved
    )
}

export function sendMessage({ processId, wallet, tags, data }, spinner) {
  let retries = "."
  const signer = createDataItemSigner(wallet)

  const retry = () => fromPromise(() => new Promise(r => setTimeout(r, 500)))()
    .map(_ => {
      spinner ? spinner.suffixText = chalk.gray('retrying' + retries) : console.log(chalk.gray('.'))
      retries += "."
      return _
    })
    .chain(fromPromise(() => connect(info).message({ process: processId, signer, tags, data })))

  return fromPromise(() => connect(info).message({ process: processId, signer, tags, data }))()
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
  //.map(result => (console.log(result), result))

}

export function spawnProcess({ wallet, src, tags }) {
  const SCHEDULER = process.env.SCHEDULER || "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA"
  const signer = createDataItemSigner(wallet)

  tags = tags.concat([{ name: 'aos-Version', value: pkg.version }])
  return fromPromise(() => connect(info).spawn({
    module: src, scheduler: SCHEDULER, signer, tags
  })
    .then(result => new Promise((resolve) => setTimeout(() => resolve(result), 500)))
  )()

}

export function monitorProcess({ id, wallet }) {
  const signer = createDataItemSigner(wallet)
  return fromPromise(() => connect(info).monitor({ process: id, signer }))()
  //.map(result => (console.log(result), result))

}

export function unmonitorProcess({ id, wallet }) {
  const signer = createDataItemSigner(wallet)
  return fromPromise(() => connect(info).unmonitor({ process: id, signer }))()
  //.map(result => (console.log(result), result))

}
