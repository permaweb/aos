import { connect, createSigner } from '@permaweb/aoconnect'
import { fromPromise, Resolved, Rejected } from 'hyper-async'
import chalk from 'chalk'
import { getPkg } from './get-pkg.js'
import cron from 'node-cron'
import fs from 'fs'
import path from 'path'
import os from 'os'
import { uniqBy, prop, keys } from 'ramda'
import Arweave from 'arweave'

const arweave = Arweave.init({})

const pkg = getPkg()
const setupMainnet = (wallet) => {
  const info = {
    GATEWAY_URL: process.env.GATEWAY_URL,
    URL : process.env.AO_URL
  } 
  return connect({
    MODE: 'mainnet',
    device: 'process@1.0',
    signer: createSigner(wallet),
    ...info 
  })
}

export function readResultMainnet(params) {
  const wallet = JSON.parse(process.env.WALLET)
  const { request } = setupMainnet(wallet) 
  return fromPromise(() => request({
      path: `/${params.process}~process@1.0/compute&slot+integer=${params.message}/results/json`,
      method: 'GET'
    }))()
    .map(res => JSON.parse(res.body))
}

const assoc = (k,v,o) => {
  o[k] = v
  return o
}

export function sendMessageMainnet({ processId, wallet, tags, data }, spinner) {
  const { request } = setupMainnet(wallet) 
  
  return fromPromise(() => 
    request({ 
      type: 'Message',
      path: `/${processId}~process@1.0/push/json~json@1.0`,
      method: 'POST',
      ...tags.filter(t => t.name !== 'device').reduce((a, t) => assoc(t.name, t.value, a), {}),
      data: data,
      'data-protocol': 'ao',
      variant: 'ao.N.1',
      target: processId
    })
  )()
    .map(res => {
      return JSON.parse(res.body)
    })
    //.map(res => res.slot)

}

export function spawnProcessMainnet({ wallet, src, tags, data }) {
  const SCHEDULER = process.env.SCHEDULER || "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA"
  const AUTHORITY = process.env.AUTHORITY || SCHEDULER
  const { request } = setupMainnet(wallet) 
 

  tags = tags.concat([{ name: 'aos-Version', value: pkg.version }])
  const params = {
    path: '/push',
    method: 'POST',
    // signingFormat: 'ANS-104',
    Type: 'Process', 
    Module: src, 
    scheduler: SCHEDULER,
    device: 'process@1.0',
    'scheduler-device': 'scheduler@1.0',
    'execution-device': 'genesis-wasm@1.0',
    'push-device': 'push@1.0',
    'scheduler-location': SCHEDULER,
    'data-protocol': 'ao',
    variant: 'ao.N.1',
    ...tags.reduce((a, t) => assoc(t.name, t.value, a), {}),
    // data: data,
    'Authority': AUTHORITY,
  }

  return fromPromise(() => request(params)
  )()
  .map(res => res.process)

}

export function monitorProcessMainnet({ id, wallet }) {
  const { monitor, createDataItemSigner } = setupRelay(wallet) 
  
  return fromPromise(() => monitor({ process: id, signer: createDataItemSigner() }))()
  //.map(result => (console.log(result), result))

}

export function unmonitorProcessMainnet({ id, wallet }) {
  const { unmonitor, createDataItemSigner } = setupRelay(wallet) 

  return fromPromise(() => unmonitor({ process: id, signer: createDataItemSigner() }))()
  //.map(result => (console.log(result), result))

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
    const { results } = setupMainnet(wallet)
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

  ct = await cron.schedule('*/2 * * * * *', printLiveMainnet)
  return ct
}
