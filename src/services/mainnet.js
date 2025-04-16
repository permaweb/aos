import { connect, createSigner } from '@permaweb/aoconnect'
import { of, fromPromise, Resolved, Rejected } from 'hyper-async'
import chalk from 'chalk'
import { getPkg } from './get-pkg.js'
import cron from 'node-cron'
import fs from 'fs'
import path from 'path'
import os from 'os'
import { uniqBy, prop, keys, assoc } from 'ramda'
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
    signer: createSigner(wallet),
    device: 'process@1.0', 
    ...info 
  })
}

export function readResultMainnet(params) {
  const wallet = JSON.parse(process.env.WALLET)
  const { request } = setupMainnet(wallet) 
  
  return fromPromise(() =>
    new Promise((resolve) => setTimeout(() => resolve(params), 0))
  )()
    .chain(fromPromise(() => request({
      path: `/${params.process}~process@1.0/compute&slot=${params.message}/results/outbox/output`,
      method: 'POST',
      target: params.process
    })
      // .then(async res => {
      //
      //   let parsedMessages = []
      //   for(let message of res.Messages) {
      //     let parsedMessage = {}
      //     for(let key in message) {
      //       if (typeof message[key] === 'function') {
      //         parsedMessage[key] = await message[key]()
      //       } else {
      //         parsedMessage[key] = message[key]
      //       }
      //     }
      //     parsedMessages.push(parsedMessage)
      //   }
      //   delete res.Messages
      //
      //   let parsedRes = {}
      //   for(let key in res) {
      //     if(typeof res[key] === 'object' && res[key].text && typeof res[key].text === 'function') {
      //       parsedRes[key] = await res[key].text()
      //     } else {
      //       parsedRes[key] = res[key]
      //     }
      //   }
      //   const finalRes = { ...parsedRes, Messages: parsedMessages }
      //   //console.log('Final mainnet response:')
      //   //console.log(finalRes)
      //   return finalRes
      // })
      .then(async res => ({ 
        process: params.process, 
        slot: params.message,  
        Output: { 
          data: res.body, 
          prompt: res.prompt 
        }
      }))
      .catch(e => {
        console.log(e)
        return ({ Error: e.message })
      })
  
    ))
    // .chain(fromPromise(async res => {
    //   if (res.Messages.length > 0) {
    //     // console.log('pushing outbox')
    //     const process = res.process
    //     const slot = res.slot
    //     const push = await request({
    //       path: `/${process}/push&slot=${slot}`,
    //       method: 'POST',
    //       target: process,
    //       'slot': slot,
    //       accept: 'application/json'
    //     }).catch(e => console.log(e))
    //     // console.log('push results', push)
    //   }
    //   return res
    // }))
    .bichain(fromPromise(() =>
      new Promise((resolve, reject) => setTimeout(() => reject(params), 500))
    ),
      Resolved
    )
}

export function sendMessageMainnet({ processId, wallet, tags, data }, spinner) {
  let retries = "."
  const { request } = setupMainnet(wallet) 
  
  return fromPromise(() => {

    const params = {
      type: 'Message',
      path: `/${processId}~process@1.0/push`,
      method: 'POST',
      target: processId,
      ...tags.filter(t => t.name !== 'device').reduce((a, t) => assoc(t.name, t.value, a), {}),
      data: data,
      'data-protocol': 'ao',
      variant: 'ao.N.1'
    }
    
    return request(params)
      .then(async res => {
        return res.slot
      })
  })()
}

export function spawnProcessMainnet({ wallet, src, tags, data }) {
  const SCHEDULER = process.env.SCHEDULER || "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA"
  const AUTHORITY = process.env.AUTHORITY
  const EXECUTION_DEVICE = process.env.EXECUTION_DEVICE
  const { request } = setupMainnet(wallet) 
  const script = pkg.hyper.script || "qMFUCmvmGqWtb95lRkt9ln60NLHDkd_JVXL7RFG6yY4"

  tags = tags.concat([{ name: 'aos-version', value: pkg.version }])
  return fromPromise(() => {
    const params = {
      path: '/push',
      method: 'POST',
      type: 'Process',
      scheduler: SCHEDULER,
      device: 'process@1.0',
      'scheduler-device': 'scheduler@1.0',
      'execution-device': EXECUTION_DEVICE,
      'push-device': 'push@1.0',
      'authority': AUTHORITY,
      'scheduler-location': SCHEDULER,
      'data-protocol': 'ao',
      variant: 'ao.N.1',
      ["script-id"]: script,
      ...tags.reduce((a, t) => assoc(t.name, t.value, a), {}),
      data: data
    }
    return request(params)
    .then(x => x.process)
})()

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

export async function liveMainnet(id, watch, wallet) {
  _watch = watch
  let ct = null
  let cursor = '1'
  let cursorFile = path.resolve(os.homedir() + `/.${id}.txt`)

  if (fs.existsSync(cursorFile)) {
    cursor = fs.readFileSync(cursorFile, 'utf-8')
  }
  // let stopped = false
  // process.stdin.on('keypress', (str, key) => {
  //   console.log({ str, key, ct, stopped })
  //   if (ct && !stopped) {
  //     ct.stop()
  //     stopped = true
  //     setTimeout(() => { ct.start(); stopped = false }, 60000)
  //   }
  // })

  const { request } = setupMainnet(wallet)
 
  let isJobRunning = false

  const checkLive = async () => {
    

    if (!isJobRunning) {

      try {
        isJobRunning = true;
        let slot = cursor
        try {
          // Handle legacy cursor format
          const parsedCursor = JSON.parse(atob(cursor.toString()) || "{}")?.ordinate 
          if (parsedCursor) {
            slot = parsedCursor
          }
        } catch (_) {} // swallow error

        // Get the current slot
        const maxSlotPath = `/${id}~process@1.0/slot/current`
        const maxSlot = await request({
          method: 'GET',
          path: maxSlotPath,
        }).then(r => r.body)

        let params = { process: id, slot: slot }
        let currSlot = params.slot
        let edges = []
        while (currSlot <= maxSlot) {
          const path = `/${params.process}~process@1.0/compute&slot=${currSlot}/results/outbox/output`
          const r = await request({
            method: 'GET',
            path
          }) 
          .catch(e => {
            console.log('ERROR: ', e.message)
            return ({})
          })

          const result = Object.keys(r).filter(key => {
            return ['Messages', 'Assignments', 'Spawns', 'Output', 'Patches', 'GasUsed'].includes(key)
          }).reduce((acc, key) => {
            acc.node[key] = r[key]
            return acc
          }, { cursor: currSlot, node: {} })
          edges.push(result)
          currSlot++
        }
        let printEdges = []
        for (let edge of edges) {
          if (edge.node?.Output?.print === true) {
            printEdges.push(edge)
          }
        }
        if (printEdges.length > 0) {
          printEdges.map(e => {
            if (!globalThis.alerts[e.cursor] && e.node?.Output?.data && e.node?.Output?.data?.length > 0) {
              globalThis.alerts[e.cursor] = e.node?.Output
            }
          })

        }
        if (edges.length > 0) {
          fs.writeFileSync(cursorFile, String(edges[edges.length - 1].cursor))
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
  //await cron.schedule('*/2 * * * * *', checkLive)

  ct = await cron.schedule('*/2 * * * * *', printLiveMainnet)
  return ct
}
