import { connect, createSigner } from '@permaweb/aoconnect-m2'
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
    new Promise((resolve) => setTimeout(() => resolve(params), 100))
  )()
    
    .chain(fromPromise(() => request({
      path: `/${params.process}/compute&slot+integer=${params.message}/results/json`,
      method: 'POST',
      target: params.process,
      'slot+integer': params.message,
      accept: 'application/json'
    })
      .then(res => ({ process: params.process, slot: params.message,  Output: res.Output, Messages: res.Messages }))
      .catch(e => {
        console.log(e)
        return ({ Error: e.message })
      })
  
    ))
    .chain(fromPromise(async res => {
      if (res.Messages.length > 0) {
        // console.log('pushing outbox')
        const process = res.process
        const slot = res.slot
        const push = await request({
          path: `/${process}/push&slot+integer=${slot}`,
          method: 'POST',
          target: process,
          'slot+integer': slot,
          accept: 'application/json'
        }).catch(e => console.log(e))
        // console.log('push results', push)
      }
      return res
    }))
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
        device: 'genesis-wasm@1.0',
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
      device: 'genesis-wasm@1.0',
      ...tags.reduce((a, t) => assoc(t.name, t.value, a), {}),
      data: data,
      'Data-Protocol': 'ao',
      Variant: 'ao.N.1'
    })
    .then(res => {
      return res.slot
    })
  ))
    .bichain(retry, Resolved)
    .bichain(retry, Resolved)
    // .bichain(retry, Resolved)
    // .bichain(retry, Resolved)
    // .bichain(retry, Resolved)
    // .bichain(retry, Resolved)
    // .bichain(retry, Resolved)
    // .bichain(retry, Resolved)
    // .bichain(retry, Resolved)
    // .bichain(retry, Resolved)    
    
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
    'execution-device': 'genesis-wasm@1.0',
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

export async function liveMainnet(id, watch, wallet) {
  _watch = watch
  let ct = null
  let cursor = 1
  let count = null
  let cursorFile = path.resolve(os.homedir() + `/.${id}.txt`)

  if (fs.existsSync(cursorFile)) {
    cursor = Number(fs.readFileSync(cursorFile, 'utf-8')) || 1
  }
  let stopped = false
  process.stdin.on('keypress', (str, key) => {
    if (ct && !stopped) {
      ct.stop()
      stopped = true
      setTimeout(() => { ct.start(); stopped = false }, 60000)
    }
  })

  const { request } = setupMainnet(wallet)
 
  let isJobRunning = false

  const checkLive = async () => {
    
    
    if (!isJobRunning) {

      try {
        isJobRunning = true;
        let params = { process: id, slot: cursor || '1' }
        
        const r = await request({
          method: 'GET',
          path: `/${params.process}/compute&slot=${params.slot}/results/json`,
          accept: 'application/json'
        })
        .then(r => {
          if (r.Output) {
            cursor = Number(cursor) + 1
          }
          return r
        })
        .catch(e => {
          console.log('ERROR: ', e.message)
          return ({})
        })

        
        let edges = []
        if (r.Output?.print === true) {
          edges.push({
            node: r
          })
        }
 
        if (edges.length > 0) {
          edges.map(e => {
            if (!globalThis.alerts[cursor] && e.node?.Output?.data && e.node?.Output?.data?.length > 0) {
              globalThis.alerts[cursor] = e.node?.Output
            }
          })

        }
        count = edges.length
        if (edges.length > 0) {
          fs.writeFileSync(cursorFile, String(cursor))
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