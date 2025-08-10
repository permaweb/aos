/**
 * mainnet-interaction.js
 *
 * This module provides utilities to interact with AO processes on Arweave's
 * Permaweb via the mainnet environment. It enables sending messages
 * (`sendMessageMainnet`), spawning new AO processes (`spawnProcessMainnet`),
 * and monitoring live process outputs (`liveMainnet`, `printLiveMainnet`). It
 * leverages functional asynchronous patterns (`hyper-async`), AO Connect SDK
 * (`@permaweb/aoconnect`), and scheduled tasks (`node-cron`) to facilitate
 * robust and continuous interactions with the Permaweb and AO network.
 */

import { connect, createSigner } from '@permaweb/aoconnect'
import { of, fromPromise, Resolved, Rejected } from 'hyper-async'
import chalk from 'chalk'
import { getPkg } from './get-pkg.js'
import cron from 'node-cron'
import fs from 'fs'
import path from 'path'
import os from 'os'
import ora from 'ora'
import readline from 'readline';
import { uniqBy, prop, keys } from 'ramda'
import Arweave from 'arweave'
import prompts from 'prompts'

const arweave = Arweave.init({})

const pkg = getPkg()
const setupMainnet = (wallet) => {
  const options = {
    MODE: 'mainnet',
    device: 'process@1.0',
    signer: createSigner(wallet),
    GATEWAY_URL: process.env.GATEWAY_URL,
    URL: process.env.AO_URL
  }
  return connect(options)
}

const assoc = (k, v, o) => {
  o[k] = v
  return o
}

const parseWasmBody = (body) => {
  try {
    return JSON.parse(body)
  } catch (e) {
    return ({ Error: 'Could not parse result!' })
  }
}

const handleResults = (resBody) =>
  resBody.info === 'hyper-aos'
    ? ({ Output: resBody.output, Error: resBody.error })
    : parseWasmBody(resBody.json?.body)

export function sendMessageMainnet({ processId, wallet, tags, data }, spinner) {
  const { request } = setupMainnet(wallet)
  const submitRequest = fromPromise(request)
  const params = {
    type: 'Message',
    path: `/${processId}~process@1.0/push/serialize~json@1.0`,
    method: 'POST',
    ...tags.filter(t => t.name !== 'device').reduce((a, t) => assoc(t.name, t.value, a), {}),
    data: data,
    'data-protocol': 'ao',
    variant: 'ao.N.1',
    target: processId,
    "accept-bundle": "true",
    "accept-codec": "httpsig@1.0",
    "signingFormat": "ANS-104"
  }

  return of(params)
    .chain(submitRequest)
    .map(prop('body'))
    .map(JSON.parse)
    .map(handleResults)

}

export function spawnProcessMainnet({ wallet, src, tags, data, isHyper }) {
  const SCHEDULER = process.env.SCHEDULER || "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA"
  const AUTHORITY = process.env.AUTHORITY || SCHEDULER

  const { request } = setupMainnet(wallet)
  const submitRequest = fromPromise(request)

  const getExecutionDevice = fromPromise(async function (params) {
    const executionDevice = await prompts({
      type: 'select',
      name: 'device',
      message: 'Please select a device',
      choices: [{ title: 'genesis-wasm@1.0', value: 'genesis-wasm@1.0' }, { title: 'lua@5.3a (experimental)', value: 'lua@5.3a' }],
      instructions: false
    }).then(res => res.device).catch(e => "genesis-wasm@1.0")
    params['execution-device'] = executionDevice
    return Promise.resolve(params)
  })

  const params = {
    path: '/push',
    method: 'POST',
    Type: 'Process',
    scheduler: SCHEDULER,
    device: 'process@1.0',
    'scheduler-device': 'scheduler@1.0',
    'push-device': 'push@1.0',
    'execution-device': 'lua@5.3a',
    'scheduler-location': SCHEDULER,
    'data-protocol': 'ao',
    variant: 'ao.N.1',
    ...tags.reduce((a, t) => assoc(t.name, t.value, a), {}),
    'Authority': AUTHORITY,
    'aos-version': pkg.version,
    'accept-bundle': 'true',
    'signingFormat': 'ANS-104'
  }
  return of(params)
    .chain(params => isHyper ? of(params) : getExecutionDevice(params))
    .map(p => {
      if (p['execution-device'] === 'lua@5.3a') {
        p.Module = process.env.AOS_MODULE || pkg.hyper.module
      } else {
        p.Module = src
      }
      return p
    })
    .chain(submitRequest)
    .map(prop('process'))
    

}

let _watch = false

export function printLiveMainnet() {
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

export async function liveMainnet(id, watch) {
  _watch = watch
  let ct = null
  let cursorFile = path.resolve(os.homedir() + `/.${id}.txt`)
  let cursor = 1
  if (fs.existsSync(cursorFile)) {
    cursor = parseInt(fs.readFileSync(cursorFile, 'utf-8'))
  }

  let isJobRunning = false

  const checkLive = async () => {
    const wallet = typeof process.env.WALLET == 'string' ? JSON.parse(process.env.WALLET) : process.env.WALLET
    const { request } = setupMainnet(wallet)
    if (!isJobRunning) {
      try {
        isJobRunning = true;

        // Get the current slot
        const currentSlotPath = `/${id}~process@1.0/slot/current/body/serialize~json@1.0`        // LIVE PARAMS
        const currentSlotParams = {
          path: currentSlotPath,
          method: 'POST',
          device: 'process@1.0',
          'data-protocol': 'ao',
          variant: 'ao.N.1',
          'aos-version': pkg.version,
          signingFormat: 'ANS-104',
          "accept-bundle": "true",
          "accept-codec": "httpsig@1.0"
        }
        const currentSlot = await request(currentSlotParams)
          .then(res => res.body)
          .then(JSON.parse)
          .then(res => res.body)

        if (isNaN(cursor)) {
          cursor = currentSlot + 1
        }
        // Eval up to the current slot
        while (cursor <= currentSlot) {

          const path = `/${id}~process@1.0/compute&slot=${cursor}/results/serialize~json@1.0`        // LIVE PARAMS
          const params = {
            path,
            method: 'POST',
            device: 'process@1.0',
            'data-protocol': 'ao',
            'scheduler-device': 'scheduler@1.0',
            'push-device': 'push@1.0',
            variant: 'ao.N.1',
            'aos-version': pkg.version,
            signingFormat: 'ANS-104',
            "accept-bundle": "true",
            "accept-codec": "httpsig@1.0"
          }
          const results = await request(params)
            .then(res => res.body)
            .then(JSON.parse)
            .then(handleResults)

          // If results, add to alerts
          if (!globalThis.alerts[cursor]) {
            globalThis.alerts[cursor] = results.Output || results.Error
          }

          // Update cursor
          if (results.Output || results.Error) {
            cursor++
            fs.writeFileSync(cursorFile, cursor.toString())
          }
        }
      } catch (e) {
        // surpress error messages #195

        // console.log(chalk.red('An error occurred with live updates...'), { e })
        // console.log('Message: ', chalk.gray(e.message))
      } finally {
        isJobRunning = false
      }
    }
  }
  ct = await cron.schedule('*/2 * * * * *', checkLive)

  await cron.schedule('*/2 * * * * *', printLiveMainnet)
  return ct
}

function formatTopupAmount(num) {
  let fixed = num.toFixed(12);
  fixed = fixed.replace(/(\.\d*?[1-9])0+$/, '$1'); // trim trailing zeros
  fixed = fixed.replace(/\.0+$/, ''); // remove trailing .0 if no decimals
  return fixed;
}

function fromDenominatedAmount(num) {
  const result = num / Math.pow(10, 12);
  return result.toFixed(12).replace(/\.?0+$/, '');
}

export async function handleNodeTopup(jwk, insufficientBalance) {
  const aoLegacy = connect({ MODE: 'legacy' });
  const aoMainnet = connect({ MODE: 'mainnet', signer: createSigner(jwk), URL: process.env.AO_URL });

  const PAYMENT = {
    token: '0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc',
    subledger: 'iVplXcMZwiu5mn0EZxY-PxAkz_A9KOU0cmRE0rwej3E',
    ticker: 'AO'
  };

  const walletAddress = await arweave.wallets.getAddress(jwk)
  console.log(`\n${chalk.gray('Wallet Address:')} ${chalk.yellow(walletAddress)}\n`);

  if (insufficientBalance) console.log(chalk.gray(`You must transfer some ${PAYMENT.ticker} to this node in order to start sending messages.`));

  let spinner = ora({
    spinner: 'dots',
    suffixText: chalk.gray(`[Getting your ${PAYMENT.ticker} balance...]`)
  });
  spinner.start();

  let balanceResponse;
  try {
    balanceResponse = await aoLegacy.dryrun({
      process: PAYMENT.token,
      tags: [
        { name: 'Action', value: 'Balance' },
        { name: 'Recipient', value: walletAddress },
      ]
    });
    spinner.stop();
  }
  catch (e) {
    spinner.stop();
    console.log(chalk.red('Error getting your balance'));
    process.exit(1);
  }

  const balance = balanceResponse?.Messages?.[0]?.Data;
  if (balance) {
    const getChalk = balance > 0 ? chalk.green : chalk.yellow;
    console.log(chalk.gray('Current balance in wallet: ' + getChalk(`${fromDenominatedAmount(balance)} ${PAYMENT.ticker}`)));
    if (balance <= 0) {
      console.log(chalk.red(`This wallet must hold some ${PAYMENT.ticker} in order to transfer to the relay.`));
      process.exit(1);
    }
  }

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const ask = (question) => new Promise(resolve => rl.question(question, answer => resolve(answer)));

  let continueWithTopup = true;

  console.log(chalk.gray('\nGetting current balance in node...'));
  let currentNodeBalance;
  try {
    const balanceRes = await fetch(`${process.env.AO_URL}/ledger~node-process@1.0/now/balance/${walletAddress}`);

    if (balanceRes.ok) {
      const balance = await balanceRes.text();
      currentNodeBalance = Number.isNaN(balance) ? 0 : balance;
    }
    else {
      currentNodeBalance = 0;
    }

    console.log(chalk.gray('Current balance in node: ' + chalk.green(`${fromDenominatedAmount(currentNodeBalance)} ${PAYMENT.ticker}\n`)));

  } catch (e) {
    console.error(e);
    process.exit(1);
  }

  if (insufficientBalance) {
    const answer = await ask(chalk.gray('Insufficient funds. Would you like to top up? (Y/N): '));
    continueWithTopup = answer.trim().toLowerCase().startsWith('y');
  }

  if (continueWithTopup) {
    let topupAmount = 0.0000001;

    if (insufficientBalance) console.log(chalk.gray('Minimum amount required: ' + chalk.green(`${formatTopupAmount(topupAmount)} ${PAYMENT.ticker}`)));
    const amountAnswer = await ask(chalk.gray(`Enter topup amount (leave blank for ${chalk.green(formatTopupAmount(topupAmount))} ${PAYMENT.ticker}): `));
    if (amountAnswer?.length) topupAmount = parseFloat(amountAnswer);

    if (isNaN(topupAmount) || topupAmount <= 0) {
      console.log(chalk.red('Invalid topup amount provided. Topup cancelled.'));
      process.exit(1);
    }

    console.log(chalk.gray('Topping up with amount: ' + chalk.green(`${formatTopupAmount(topupAmount)} ${PAYMENT.ticker}\n`)));

    rl.close();
    spinner = ora({
      spinner: 'dots',
      suffixText: chalk.gray('[Transferring balance to node...]')
    });
    spinner.start();

    const sendQuantity = (topupAmount * Math.pow(10, 12)).toString();

    const currentBetaGZAOBalance = (await aoLegacy.dryrun({
      process: PAYMENT.subledger,
      tags: [
        { name: 'Action', value: 'Balance' },
        { name: 'Recipient', value: walletAddress }
      ]
    })).Messages[0].Data;

    const transferId = await aoLegacy.message({
      process: PAYMENT.token,
      tags: [
        { name: 'Action', value: 'Transfer' },
        { name: 'Quantity', value: sendQuantity },
        { name: 'Recipient', value: PAYMENT.subledger },
      ],
      signer: createSigner(jwk)
    });

    await aoLegacy.result({
      process: PAYMENT.token,
      message: transferId
    });

    let updatedBetaGZAOBalance;
    do {
      await new Promise((r) => setTimeout(r, 2000));
      updatedBetaGZAOBalance = (await aoLegacy.dryrun({
        process: PAYMENT.subledger,
        tags: [
          { name: 'Action', value: 'Balance' },
          { name: 'Recipient', value: walletAddress }
        ]
      })).Messages[0].Data;
    }
    while (updatedBetaGZAOBalance === currentBetaGZAOBalance)

    const ledgerAddressRes = await fetch(`${process.env.AO_URL}/ledger~node-process@1.0/commitments/keys/1`);
    const ledgerAddress = await ledgerAddressRes.text();

    const transferParams = {
      type: 'Message',
      path: `/${PAYMENT.subledger}~process@1.0/push/serialize~json@1.0`,
      method: 'POST',
      'data-protocol': 'ao',
      variant: 'ao.N.1',
      target: PAYMENT.subledger,
      'accept-bundle': 'true',
      'accept-codec': 'httpsig@1.0',
      'signingFormat': 'ANS-104',
      action: 'Transfer',
      Recipient: walletAddress,
      Route: ledgerAddress,
      Quantity: sendQuantity
    }

    const transferRes = await aoMainnet.request(transferParams);
    if (transferRes.status === '200') {
      let updatedNodeBalance;
      do {
        try {
          const balanceRes = await fetch(`${process.env.AO_URL}/ledger~node-process@1.0/now/balance/${walletAddress}`);

          if (balanceRes.ok) {
            const balance = await balanceRes.text();
            updatedNodeBalance = Number.isNaN(balance) ? 0 : balance;
          }
          else {
            updatedNodeBalance = 0;
          }

          if (currentNodeBalance !== updatedNodeBalance) {
            spinner.stop();
            console.log(chalk.gray('Updated balance in node: ' + chalk.green(`${fromDenominatedAmount(updatedNodeBalance)} ${PAYMENT.ticker}`)));
          }

        } catch (e) {
          console.error(e);
          process.exit(1);
        }
      }
      while (currentNodeBalance === updatedNodeBalance);

      return true;
    }
    else {
      console.log(chalk.red('Error handling node topup.'));
      process.exit(1);
    }
  }
}
