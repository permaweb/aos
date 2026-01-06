/**
 * mainnet-interaction.js
 *
 * This module provides utilities to interact with AO processes on Arweave's
 * Permaweb via the mainnet environment. It enables sending messages
 * (`sendMessageMainnet`), spawning new AO processes (`spawnProcessMainnet`),
 * and monitoring live process outputs (`liveMainnet`, `printLiveMainnet`). It
 * uses async/await for clearer control flow.
 */

import { connect, createSigner } from '@permaweb/aoconnect'
import { chalk } from '../utils/colors.js'
import { getPkg } from './get-pkg.js'
import cron from 'node-cron'
import fs from 'fs'
import path from 'path'
import os from 'os'
import ora from 'ora'
import readline from 'readline'
import { keys } from 'ramda'
import { config } from '../config.js'
import Arweave from 'arweave'
import { printWithoutDisruption } from '../utils/terminal.js'

const arweave = Arweave.init({})

const pkg = getPkg()

const setupMainnet = wallet => {
  const options = {
    MODE: 'mainnet',
    signer: createSigner(wallet),
    GATEWAY_URL: process.env.GATEWAY_URL,
    URL: process.env.AO_URL,
    SCHEDULER: process.env.SCHEDULER ?? config.addresses.SCHEDULER_MAINNET
  }
  return connect(options)
}

const parseWasmBody = body => {
  try {
    return JSON.parse(body)
  } catch (e) {
    return { Error: 'Could not parse result!' }
  }
}

const resolveAuthority = async () => {
  if (process.env.AUTHORITY) return process.env.AUTHORITY;
  else {
    const authority = await fetch(`${process.env.AO_URL}/~meta@1.0/info/address`).then(res => res.text());
    return authority;
  }
}

export async function spawnProcessMainnet({ wallet, src, tags, data }) {
  const { spawn } = setupMainnet(wallet)
  try {
    const authority = await resolveAuthority();

    const processId = await spawn({
      tags: [
        ...tags,
        { name: 'aos-version', value: pkg.version },
        { name: 'process-timestamp', value: Date.now().toString() }
      ],
      authority: authority,
      module: src,
      data: data
    })
    return processId
  } catch (e) {
    console.error(e)
    throw new Error(e.message ?? 'Error spawning process')
  }
}

export async function sendMessageMainnet({ processId, wallet, tags, data }) {
  const { message, result } = setupMainnet(wallet)
  try {
    // Pause cron jobs to prevent race conditions
    _cronPaused = true

    const slot = await message({
      process: processId,
      tags: [...tags, { name: 'message-timestamp', value: Date.now().toString() }],
      data: data
    })

    // Fetch the result
    const resultData = await result({
      slot: slot,
      process: processId
    })

    // Update cursor file and mark slot as processed to prevent liveMainnet from re-processing this result
    const cursorFile = path.resolve(os.homedir() + `/.${processId}.txt`)
    fs.writeFileSync(cursorFile, slot.toString())

    // Mark this slot as already processed
    _processedSlots.add(parseInt(slot))

    // Resume cron jobs
    _cronPaused = false

    return resultData
  } catch (e) {
    // Resume cron jobs even on error
    _cronPaused = false
    console.error(e)
    throw new Error(e.message ?? 'Error sending message')
  }
}

export async function readResultMainnet({ message, process: processId }) {
  const wallet =
    typeof process.env.WALLET == 'string' ? JSON.parse(process.env.WALLET) : process.env.WALLET
  const { result } = setupMainnet(wallet)

  try {
    return await result({
      message: message,
      process: processId
    })
  } catch (e) {
    throw new Error(e.message ?? 'Error reading result')
  }
}

let _watch = false
let _processedSlots = new Set()
let _cronPaused = false

export function printLiveMainnet() {
  // Don't print if cron is paused (during sendMessageMainnet)
  if (_cronPaused) return

  keys(globalThis.alerts).map(k => {
    if (globalThis.alerts[k] && globalThis.alerts[k].print) {
      // Double-check we haven't already printed this slot
      const slotNum = parseInt(k)
      if (_processedSlots.has(slotNum)) {
        globalThis.alerts[k].print = false
        return
      }

      globalThis.alerts[k].print = false
      _processedSlots.add(slotNum)

      // Update prompt if needed
      if (globalThis.alerts[k].prompt) {
        globalThis.prompt = globalThis.alerts[k].prompt
        if (globalThis.setPrompt) {
          globalThis.setPrompt(globalThis.prompt)
        }
      }

      // Print without disrupting user input (don't show separator - it's handled by prompt)
      if (globalThis.rl) {
        printWithoutDisruption(globalThis.alerts[k].data, globalThis.rl, false)
      } else {
        // Fallback if readline not available
        process.stdout.write('\n' + globalThis.alerts[k].data + '\n')
      }
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
    // Don't run if cron is paused (during sendMessageMainnet)
    if (_cronPaused) return

    const wallet =
      typeof process.env.WALLET == 'string' ? JSON.parse(process.env.WALLET) : process.env.WALLET

    const { results } = setupMainnet(wallet)

    if (!isJobRunning) {
      try {
        isJobRunning = true

        const resultsData = await results({ process: id })

        if (resultsData?.edges?.length > 0) {
          const edge = resultsData.edges[0]
          const currentSlot = parseInt(edge.cursor)
          const resultNode = edge.node

          if (isNaN(cursor)) {
            cursor = currentSlot
          }

          // Only process if current slot is greater than our cursor AND hasn't been processed yet
          // Cursor represents the last slot we've already processed
          if (currentSlot > cursor && !_processedSlots.has(currentSlot)) {
            // Add to alerts (will be printed by printLiveMainnet)
            if (!globalThis.alerts[currentSlot]) {
              globalThis.alerts[currentSlot] = {
                data: resultNode.Output?.data?.output || resultNode.Output?.data || '',
                prompt: resultNode.Output?.data?.prompt || resultNode.Output?.prompt,
                print: true
              }
            }

            // Update cursor (don't add to _processedSlots yet - that happens when printed)
            cursor = currentSlot
            fs.writeFileSync(cursorFile, cursor.toString())
          }
        }
      } catch (e) {} finally {
        isJobRunning = false
      }
    }
  }
  ct = await cron.schedule('*/2 * * * * *', checkLive)

  // Also print on a schedule to show async messages from other processes
  await cron.schedule('*/2 * * * * *', printLiveMainnet)
  return ct
}

function formatTopupAmount(num) {
  let fixed = num.toFixed(12)
  fixed = fixed.replace(/(\.\d*?[1-9])0+$/, '$1') // trim trailing zeros
  fixed = fixed.replace(/\.0+$/, '') // remove trailing .0 if no decimals
  return fixed
}

function fromDenominatedAmount(num) {
  const result = num / Math.pow(10, 12)
  return result.toFixed(12).replace(/\.?0+$/, '')
}

export async function handleNodeTopup(jwk, insufficientBalance) {
  const aoLegacy = connect({ MODE: 'legacy' })
  const aoMainnet = connect({ MODE: 'mainnet', signer: createSigner(jwk), URL: process.env.AO_URL })

  const PAYMENT = {
    token: '0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc',
    subledger: 'iVplXcMZwiu5mn0EZxY-PxAkz_A9KOU0cmRE0rwej3E',
    ticker: 'AO'
  }

  const walletAddress = await arweave.wallets.getAddress(jwk)
  console.log(`\n${chalk.gray('Wallet Address:')} ${chalk.yellow(walletAddress)}\n`)

  if (insufficientBalance)
    console.log(
      chalk.gray(
        `You must transfer some ${PAYMENT.ticker} to this node in order to start sending messages.`
      )
    )

  let spinner = ora({
    spinner: 'dots',
    suffixText: chalk.gray(`[Getting your ${PAYMENT.ticker} balance...]`)
  })
  spinner.start()

  let balanceResponse
  try {
    balanceResponse = await aoLegacy.dryrun({
      process: PAYMENT.token,
      tags: [
        { name: 'Action', value: 'Balance' },
        { name: 'Recipient', value: walletAddress }
      ]
    })
    spinner.stop()
  } catch (e) {
    spinner.stop()
    console.log(chalk.red('Error getting your balance'))
    process.exit(1)
  }

  const balance = balanceResponse?.Messages?.[0]?.Data
  if (balance) {
    const getChalk = balance > 0 ? chalk.green : chalk.yellow
    console.log(
      chalk.gray(
        'Current balance in wallet: ' +
        getChalk(`${fromDenominatedAmount(balance)} ${PAYMENT.ticker}`)
      )
    )
    if (balance <= 0) {
      console.log(
        chalk.red(`This wallet must hold some ${PAYMENT.ticker} in order to transfer to the relay.`)
      )
      process.exit(1)
    }
  }

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  })

  const ask = question => new Promise(resolve => rl.question(question, answer => resolve(answer)))

  let continueWithTopup = true

  console.log(chalk.gray('\nGetting current balance in node...'))
  let currentNodeBalance
  try {
    const balanceRes = await fetch(
      `${process.env.AO_URL}/ledger~node-process@1.0/now/balance/${walletAddress}`
    )

    if (balanceRes.ok) {
      const balance = await balanceRes.text()
      currentNodeBalance = Number.isNaN(balance) ? 0 : balance
    } else {
      currentNodeBalance = 0
    }

    console.log(
      chalk.gray(
        'Current balance in node: ' +
        chalk.green(`${fromDenominatedAmount(currentNodeBalance)} ${PAYMENT.ticker}\n`)
      )
    )
  } catch (e) {
    console.error(e)
    process.exit(1)
  }

  if (insufficientBalance) {
    const answer = await ask(chalk.gray('Insufficient funds. Would you like to top up? (Y/N): '))
    continueWithTopup = answer.trim().toLowerCase().startsWith('y')
  }

  if (continueWithTopup) {
    let topupAmount = 0.0000001

    if (insufficientBalance)
      console.log(
        chalk.gray(
          'Minimum amount required: ' +
          chalk.green(`${formatTopupAmount(topupAmount)} ${PAYMENT.ticker}`)
        )
      )
    const amountAnswer = await ask(
      chalk.gray(
        `Enter topup amount (leave blank for ${chalk.green(formatTopupAmount(topupAmount))} ${PAYMENT.ticker}): `
      )
    )
    if (amountAnswer?.length) topupAmount = parseFloat(amountAnswer)

    if (isNaN(topupAmount) || topupAmount <= 0) {
      console.log(chalk.red('Invalid topup amount provided. Topup cancelled.'))
      process.exit(1)
    }

    console.log(
      chalk.gray(
        'Topping up with amount: ' +
        chalk.green(`${formatTopupAmount(topupAmount)} ${PAYMENT.ticker}\n`)
      )
    )

    rl.close()
    spinner = ora({
      spinner: 'dots',
      suffixText: chalk.gray('[Transferring balance to node...]')
    })
    spinner.start()

    const sendQuantity = (topupAmount * Math.pow(10, 12)).toString()

    const currentBetaGZAOBalance = (
      await aoLegacy.dryrun({
        process: PAYMENT.subledger,
        tags: [
          { name: 'Action', value: 'Balance' },
          { name: 'Recipient', value: walletAddress }
        ]
      })
    ).Messages[0].Data

    const transferId = await aoLegacy.message({
      process: PAYMENT.token,
      tags: [
        { name: 'Action', value: 'Transfer' },
        { name: 'Quantity', value: sendQuantity },
        { name: 'Recipient', value: PAYMENT.subledger }
      ],
      signer: createSigner(jwk)
    })

    await aoLegacy.result({
      process: PAYMENT.token,
      message: transferId
    })

    let updatedBetaGZAOBalance
    do {
      await new Promise(r => setTimeout(r, 2000))
      updatedBetaGZAOBalance = (
        await aoLegacy.dryrun({
          process: PAYMENT.subledger,
          tags: [
            { name: 'Action', value: 'Balance' },
            { name: 'Recipient', value: walletAddress }
          ]
        })
      ).Messages[0].Data
    } while (updatedBetaGZAOBalance === currentBetaGZAOBalance)

    const ledgerAddressRes = await fetch(
      `${process.env.AO_URL}/ledger~node-process@1.0/commitments/keys/1`
    )
    const ledgerAddress = await ledgerAddressRes.text()

    const transferParams = {
      type: 'Message',
      path: `/${PAYMENT.subledger}~process@1.0/push/serialize~json@1.0`,
      method: 'POST',
      'data-protocol': 'ao',
      variant: 'ao.N.1',
      target: PAYMENT.subledger,
      'signing-format': 'ANS-104',
      action: 'Transfer',
      recipient: walletAddress,
      route: ledgerAddress,
      quantity: sendQuantity
    }

    const transferRes = await aoMainnet.request(transferParams)
    if (transferRes.status === '200') {
      let updatedNodeBalance
      do {
        try {
          const balanceRes = await fetch(
            `${process.env.AO_URL}/ledger~node-process@1.0/now/balance/${walletAddress}`
          )

          if (balanceRes.ok) {
            const balance = await balanceRes.text()
            updatedNodeBalance = Number.isNaN(balance) ? 0 : balance
          } else {
            updatedNodeBalance = 0
          }

          if (currentNodeBalance !== updatedNodeBalance) {
            spinner.stop()
            console.log(
              chalk.gray(
                'Updated balance in node: ' +
                chalk.green(`${fromDenominatedAmount(updatedNodeBalance)} ${PAYMENT.ticker}`)
              )
            )
          }
        } catch (e) {
          console.error(e)
          process.exit(1)
        }
      } while (currentNodeBalance === updatedNodeBalance)

      return true
    } else {
      console.log(chalk.red('Error handling node topup.'))
      process.exit(1)
    }
  }
}
