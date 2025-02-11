import { createPrivateKey } from 'node:crypto'
import { connect } from '@permaweb/aoconnect'
import { fromPromise, Resolved, Rejected } from 'hyper-async'
import readline from 'readline';
import ora from 'ora'
import chalk from 'chalk'
import { getPkg } from './get-pkg.js'
import cron from 'node-cron'
import fs from 'fs'
import path from 'path'
import os from 'os'
import { uniqBy, prop, keys } from 'ramda'
import Arweave from 'arweave'

import { httpbis, createSigner } from 'http-message-signatures'

const { signMessage } = httpbis
const arweave = Arweave.init({})

const pkg = getPkg()

const setupRelay = (wallet) => {
  const info = {
    GATEWAY_URL: process.env.GATEWAY_URL,
    CU_URL: process.env.CU_URL ?? 'http://cu.s451-comm3-main.xyz',
    MU_URL: process.env.MU_URL ?? 'http://mu.s451-comm3-main.xyz',
    RELAY_URL: process.env.RELAY_URL ?? 'http://137.220.36.155',
    SCHEDULER: 'eyhFer638JG-fJFEC3X3Q5kAl78aTe1eljYDiQo0vuU'
  }
  return connect({
    MODE: 'relay',
    wallet,
    ...info
  })
}

export function readResultRelay(params) {
  const wallet = JSON.parse(process.env.WALLET)
  const { result } = setupRelay(wallet)
  return fromPromise(() =>
    new Promise((resolve) => setTimeout(() => resolve(params), 1000))
  )()
    .chain(fromPromise(() => result(params)))
    .bichain(fromPromise(() =>
      new Promise((resolve, reject) => setTimeout(() => reject(params), 500))
    ),
      Resolved
    )
}

export function dryrunRelay({ processId, wallet, tags, data }, spinnner) {
  const { dryrun } = setupRelay(wallet)
  return fromPromise(() =>
    arweave.wallets.jwkToAddress(wallet).then(Owner =>
      dryrun({ process: processId, Owner, tags, data })
    )
  )()
}


export function sendMessageRelay({ processId, wallet, tags, data }, spinner) {
  let retries = "."
  const { message, createDataItemSigner } = setupRelay(wallet)

  const retry = () => fromPromise(() => new Promise(r => setTimeout(r, 500)))()
    .map(_ => {
      spinner ? spinner.suffixText = chalk.gray('[Processing' + retries + ']') : console.log(chalk.gray('.'))
      retries += "."
      return _
    })
    .chain(fromPromise(() => message({ process: processId, signer: createDataItemSigner(), tags, data })))

  return fromPromise(() =>
    new Promise((resolve) => setTimeout(() => resolve(), 500))
  )().chain(fromPromise(() =>
    message({ process: processId, signer: createDataItemSigner(), tags, data })
  ))
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

}

export function spawnProcessRelay({ wallet, src, tags, data }) {
  const SCHEDULER = process.env.SCHEDULER || "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA"
  const { spawn, createDataItemSigner } = setupRelay(wallet)


  tags = tags.concat([
    { name: 'aos-Version', value: pkg.version }, 
    { name: 'Authority', value: 'tYRUqrx6zuFFiix3MoSBYSPP3nMzi5EKf-lVYDEQz8A' }
  ])
  return fromPromise(() => spawn({
    module: src, scheduler: SCHEDULER, signer: createDataItemSigner(), tags, data
  })
    .then(result => new Promise((resolve) => setTimeout(() => resolve(result), 500)))
  )()

}

export function monitorProcessRelay({ id, wallet }) {
  const { monitor, createDataItemSigner } = setupRelay(wallet)

  return fromPromise(() => monitor({ process: id, signer: createDataItemSigner() }))()
  //.map(result => (console.log(result), result))

}

export function unmonitorProcessRelay({ id, wallet }) {
  const { unmonitor, createDataItemSigner } = setupRelay(wallet)

  return fromPromise(() => unmonitor({ process: id, signer: createDataItemSigner() }))()
  //.map(result => (console.log(result), result))

}

let _watch = false

export function printLiveRelay() {
  keys(globalThis.alerts).map(k => {
    if (globalThis.alerts[k].print) {
      globalThis.alerts[k].print = false

      if (!_watch) {
        process.stdout.write("\u001b[2K");
      } else {
        process.stdout.write('\n')
      }
      process.stdout.write("\u001b[0G" + globalThis.alerts[k].data)

      globalThis.prompt = globalThis.alerts[k].prompt || "aos> "
      globalThis.setPrompt(globalThis.prompt || "aos> ")
      process.stdout.write('\n' + globalThis.prompt || "aos> ")

    }
  })

}

export async function liveRelay(id, watch) {
  _watch = watch
  let ct = null
  let cursor = null
  let count = null
  let cursorFile = path.resolve(os.homedir() + `/.${id}.txt`)

  if (fs.existsSync(cursorFile)) {
    cursor = fs.readFileSync(cursorFile, 'utf-8')
  }
  let stopped = false
  process.stdin.on('keypress', (str, key) => {
    if (ct && !stopped) {
      ct.stop()
      stopped = true
      setTimeout(() => { ct.start(); stopped = false }, 60000)
    }
  })

  let isJobRunning = false

  const checkLive = async () => {
    const wallet = process.env.WALLET
    const { results } = setupRelay(wallet)
    if (!isJobRunning) {

      try {
        isJobRunning = true;
        let params = { process: id, limit: 1000 }
        if (cursor) {
          params["from"] = cursor
        } else {
          params["limit"] = 5
          params["sort"] = "DESC"
        }

        const _relayResults = await results(params)

        let edges = uniqBy(prop('cursor'))(_relayResults.edges.filter(function (e) {
          if (e.node?.Output?.print === true) {
            return true
          }
          if (e.cursor === cursor) {
            return false
          }
          return false
        }))

        // Sort the edges by ordinate value to ensure they are printed in the correct order.
        // TODO: Handle sorting with Cron jobs, considering nonces and timestamps. Review cursor usage for compatibility with future CU implementations.
        edges = edges.sort((a, b) => JSON.parse(atob(a.cursor)).ordinate - JSON.parse(atob(b.cursor)).ordinate);

        // --- peek on previous line and if delete line if last prompt.
        // --- key event can detect 
        // count !== null && 
        if (edges.length > 0) {
          edges.map(e => {
            if (!globalThis.alerts[e.cursor]) {
              globalThis.alerts[e.cursor] = e.node?.Output
            }
          })

        }
        count = edges.length
        if (results.edges.length > 0) {
          cursor = results.edges[results.edges.length - 1].cursor
          fs.writeFileSync(cursorFile, cursor)
        }
        //process.nextTick(() => null)

      } catch (e) {
        // surpress error messages #195

        // console.log(chalk.red('An error occurred with live updates...'))
        // console.log('Message: ', chalk.gray(e.message))
      } finally {
        isJobRunning = false
      }
    }
  }
  await cron.schedule('*/2 * * * * *', checkLive)

  ct = await cron.schedule('*/2 * * * * *', printLiveRelay)
  return ct
}

function httpSigName(address) {
  const decoded = Buffer.from(address, 'base64url')
  const first8Bytes = decoded.subarray(1, 9)
  const hexString = [...first8Bytes].map(byte => byte.toString(16).padStart(2, '0')).join('')
  return `http-sig-${hexString}`
}

function formatTopupAmount(num) {
  let fixed = num.toFixed(12);
  fixed = fixed.replace(/(\.\d*?[1-9])0+$/, '$1'); // trim trailing zeros
  fixed = fixed.replace(/\.0+$/, ''); // remove trailing .0 if no decimals
  return fixed;
}

export async function handleRelayTopup(jwk) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const ask = (question) => new Promise(resolve => rl.question(question, answer => resolve(answer)));

  const answer = await ask(chalk.gray('Insufficient funds. Would you like to top up? (Y/N): '));
  if (answer.trim().toLowerCase().startsWith('y')) {
    let topupAmount = 0.0000001; // TODO: Get minimum amount
    const maxBalanceRetries = 20;

    console.log(chalk.gray(`Minimum amount required: (${formatTopupAmount(topupAmount)} AO)`));
    const amountAnswer = await ask(chalk.gray('Enter topup amount (leave blank for minimum): '));
    if (amountAnswer?.length) topupAmount = parseFloat(amountAnswer);

    if (isNaN(topupAmount) || topupAmount <= 0) {
      console.log(chalk.red('Invalid topup amount provided. Topup cancelled.'));
      rl.close();
      return false;
    }

    console.log(chalk.gray('Proceeding with topup...'));
    console.log(chalk.green(`Topping up with amount: ${formatTopupAmount(topupAmount)} AO`));

    const spinner = ora({
      spinner: 'dots',
      suffixText: chalk.gray('[Handling relay topup...]')
    });
    spinner.start();

    const address = await arweave.wallets.getAddress(jwk);
    const privateKey = createPrivateKey({ key: jwk, format: 'jwk' });
    const signer = createSigner(privateKey, 'rsa-pss-sha512', address);
    const params = ['alg', 'keyid'].sort();

    const relay = {
      address: 'yTVz5K0XU52lD9O0iHh42wgBGSXgsPcu7wEY8GqWnFY',
      url: `${process.env.RELAY_URL}/~simple-pay@1.0/balance`
    };

    const relayUrl = new URL(relay.url);
    const request = {
      url: relayUrl,
      method: 'GET',
      headers: {
        'path': relayUrl.pathname,
      }
    };

    const { method, headers } = await signMessage({
      key: signer,
      fields: [...Object.keys(request.headers)].sort(),
      name: httpSigName(address),
      params
    }, request);

    let initialBalance;
    try {
      const response = await fetch(relay.url, { method, headers });
      const balance = parseInt(await response.text(), 10);
      initialBalance = Number.isNaN(balance) ? 0 : balance;
      console.log(chalk.gray(`Initial balance before transfer: ${initialBalance} AO`));
    } catch (e) {
      console.error(chalk.red('Error fetching initial balance:'), e);
    }

    const sendQuantity = (topupAmount * Math.pow(10, 12)).toString();
    const { message, createDataItemSigner } = connect();

    try {
      const transferId = await message({
        process: '0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc',
        signer: createDataItemSigner(jwk),
        tags: [
          { name: 'Action', value: 'Transfer' },
          { name: 'Recipient', value: relay.address },
          { name: 'Quantity', value: sendQuantity },
        ]
      });
      console.log(`\nTransfer ID: ${transferId}`);
    } catch (e) {
      console.error(chalk.red('Error sending transfer message:'), e);
    }

    let newBalance;
    for (let attempt = 1; attempt <= maxBalanceRetries; attempt++) {
      try {
        let response = await fetch(relay.url, { method, headers });
        const balance = parseInt(await response.text(), 10);
        newBalance = Number.isNaN(balance) ? 0 : balance;
        if (newBalance !== initialBalance) {
          spinner.stop();
          console.log(chalk.green(`Balance updated from ${formatTopupAmount(initialBalance)} to ${formatTopupAmount(newBalance)} AO`));
          break;
        }
      } catch (e) {
        console.error('Error fetching balance endpoint:', e);
      }
      await new Promise(resolve => setTimeout(resolve, 1000));
    }

    rl.close();
    return true;
  } else {
    console.log(chalk.red('Topup cancelled'));
    rl.close();
    return false;
  }
}