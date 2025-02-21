import { connect, createSigner } from '@permaweb/aoconnect'
import { fromPromise, Resolved, Rejected } from 'hyper-async'
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
    new Promise((resolve) => setTimeout(() => resolve(params), 1000))
  )()
    .chain(fromPromise(() => request({
      path: `/${params.process}/compute&slot+integer=${params.message}/results/json`,
      method: 'POST',
      target: params.process,
      'slot+integer': params.message,
      accept: 'application/json'
    }).then(async res => ({ Output: await res.Output.json()}))
  
    ))
    
    .bichain(fromPromise(() =>
      new Promise((resolve, reject) => setTimeout(() => reject(params), 500))
    ),
      Resolved
    )
}

export function dryrunMainnet({ processId, wallet, tags, data }, spinnner) {
  const { request } = setupMainnet(wallet)
  return fromPromise(() =>
    arweave.wallets.jwkToAddress(wallet).then(Owner =>
      request({
        path: `/~relay@1.0?relay-path=http://localhost:3000/dryrun/${processId}`,
        method: 'POST',
        body: JSON.stringify({
          Target: processId,
          Owner,
          tags,
          data
        })
      })
      //dryrun({ process: processId, Owner, tags, data })
    )
  )()
}


export function sendMessageMainnet({ processId, wallet, tags, data }, spinner) {
  let retries = "."
  const { request } = setupMainnet(wallet) 
  
  const retry = () => fromPromise(() => new Promise(r => setTimeout(r, 500)))()
    .map(_ => {
      spinner ? spinner.suffixText = chalk.gray('[Processing' + retries + ']') : console.log(chalk.gray('.'))
      retries += "."
      return _
    })
    .chain(fromPromise(() => {
      return request({
        type: 'Message',
        path: `${processId}/schedule`,
        method: 'POST',
        ...tags.reduce((a, t) => assoc(t.name, t.value, a), {}),
        data: data,
        'Data-Protocol': 'ao',
        Variant: 'ao.N.1'
      }) 
    }))
  
  return fromPromise(() =>
    new Promise((resolve) => setTimeout(() => resolve(), 500))
  )().chain(fromPromise(() => request({
      type: 'Message',
      path: `${processId}/schedule`,
      method: 'POST',
      ...tags.reduce((a, t) => assoc(t.name, t.value, a), {}),
      data: data,
      'Data-Protocol': 'ao',
      Variant: 'ao.N.1'
    })
    .then(res => res.Messages.length > 0
    ? request({
        path: `/${process}/push&slot+integer=${res.slot}`,
        method: 'POST',
        target: process,
        'slot+integer': res.slot,
        data: '1984'
      }).then(push => {
        console.log('push', push)
        return Promise.resolve(res)
      }).catch(err => {
        console.log(err)
        return Promise.resolve(res)
      })
    : Promise.resolve(res)) 
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
    
    //   fromPromise(res => {
    //     if (res.Messages.length > 0) {
    //       console.log('push')
    //       // force push
    //       return request({
    //         path: `/${process}/push&slot+integer=${res.slot}`,
    //         method: 'POST',
    //         target: process,
    //         'slot+integer': res.slot,
    //         accept: 'application/json'
    //       }).then(push => res)
    //     }
    //     return Resolved(res)
    // }))

}

export function spawnProcessMainnet({ wallet, src, tags, data }) {
  const SCHEDULER = process.env.SCHEDULER || "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA"
  const { request } = setupMainnet(wallet) 
 

  tags = tags.concat([{ name: 'aos-Version', value: pkg.version }])
  return fromPromise(() => request({
    path: '/schedule',
    method: 'POST',
    type: 'Process',
    scheduler: SCHEDULER,
    module: src,
    device: 'process@1.0',
    'scheduler-device': 'scheduler@1.0',
    'execution-device': 'compute-lite@1.0',
    authority: SCHEDULER,
    'scheduler-location': SCHEDULER,
    'Data-Protocol': 'ao',
    Variant: 'ao.N.1',
    ...tags.reduce((a, t) => assoc(t.name, t.value, a), {}),
    data: data
  })
   
    .then(x => x.process)
    .then(result => new Promise((resolve) => setTimeout(() => resolve(result), 500)))
  )()

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