import { connect, createDataItemSigner } from "@permaweb/aoconnect"
import { fromPromise, Resolved, Rejected } from 'hyper-async'
import chalk from 'chalk'

export function sendMessage({ processId, wallet, tags, data }, spinner) {
  let retries = "."
  const signer = createDataItemSigner(wallet)
  const info = {}
  if (process.env.CU_URL) {
    info['CU_URL'] = process.env.CU_URL || 'https://cu.ao-testnet.xyz'
  }
  if (process.env.MU_URL) {
    info['MU_URL'] = process.env.MU_URL || 'https://mu.ao-testnet.xyz'
  }
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
