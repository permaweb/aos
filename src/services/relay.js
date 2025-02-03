import { connect } from '@permaweb/aoconnect'
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
const setupRelay = (wallet) => {
  const info = {
    GATEWAY_URL: process.env.GATEWAY_URL,
    CU_URL: process.env.CU_URL,
    MU_URL: process.env.MU_URL,
    URL : process.env.RELAY_URL
  } 
  return connect.hb({
    wallet, 
    ...info 
  })
}

const dummy = {
  kty: 'RSA',
  n: 'qMJjVaB2vI9sHPoLDEt5bvPwIZ8h56EU_uB2ETg_K4jHoSMxCvSJSg0Cv1p5pTQ7k2twGHtqDrNchp3ladR-p3KZNgF04KSeZUAAd3XsMiMVAni1QgZoazIsf6luPuWdISRCq0uo9UDSajHvQReFOz2ReoSiDen4UDzBX9qTQWr_wwfon2aN8SkUxUOlIRz6gwK9L2UxH-iOFWUlTkth7E-6u7HCSPHo-9Q9u7-ZGMqaCtpEL0gF5clpTbALcPmNPd919pA0OGb-1L3fxULxJf-ijHsHdnXr5bzp4kHdHBJUIoahCMZQhbo_ClkKeCvhfrSqqpW6u0x41RsB_lMrfJmlbaMB-4h0TKlNFEVyfTcXnXk9YyGOUqj4z1cOTeqOSBEscgp1htQ3kBALXNddIPWF4c5_DbYdFVhRxLLPOPaPptliMWgWTHJJHA0kJLrnJXdLiRJsc6PC__775BKfvdmZBpmjbyQcwTNtvhZFZXdfrb4INxCB1kGeyQneJsQNGMo7StqlznAeGJj5V5D5lGDOD9ud9iSjsQKHdT7rRgVtrYXhC1mMM6XhYzMfn_-5B9-oehsdzcyYOh70uU0hxqYtplNJqkwfdmhxTqbDlBL3P-CvrtXDIX0YoZlC44XQtoL9rOgh1nv7-Qq0Srsglr427oDyP1oU03Cgf1QCwg8',
  e: 'AQAB',
  d: 'DmL7-unCFZMYgWPjmzm38XiESSl6x3dZBd1200L7R6fSdO8-GBP-vDxdtphs9GN-jLPFC6FByl0KD0PYsev2nCnN2-fF4fzGsBUDtSttZlzNRreppCZNso3Fc2CrUFtcyN2BfX7muXm8NmdpYSAzMHiwNUSnWA5RJ-32Akjs8s-_XA4Ji8U_Zoa9CZAZvLfut0p9fFPhGzpFGpfT1Vfh0jZ90dB2oqdU2FsgpCfSUmW7Oh-fXnSCZDOGcaQHZaswmky5jrp-aSyGnvZM5FEvo7CmV9mJKlUlNiGjwrEgu2rol0To54mYhb3579Tlapc7EwUt43r-P0dmqawywE6wzzwB5QpKYCR8_RtQE0NLgdSEZEVz6ErPglvqcPxcs8Jv0bBSFEMx0pjY3Dh_mul5qr2rOgfybWrKP5YL_tK8dmIvXl4p3XBf-DZeha-ZlNlZzQPCLjl0kSEiAMBIlH9Ltbvrt0JeY7C7eTSeUTkgo-DKVXoYpFkuZipfvlVroadNyjV7rCFJF-shAL8sS8mm6dS2QTNLK7xWxgHACIgC6Bc2M9sqpxlExMFaZrC9gdLUHdkWg3Z5eB7jpkHCv4JOwi0Q1bSpfbng4lAoBNDmycyKlRNweO6TZQLw53s57Sl2HvsTGkoGviyjXezfzlU1NvQTpeba2srN45igUeD-QRk',
  p: '2qpm7heo2UBZOKB-CM95yL1bvSP3hOSs3rLs1YgtLytCHuZQ5Zp--JoBjQY4_mMh0288Y9nKidzr6mRt1PqvVoO2wPH9kiRTsOE0Q8w1FAClwDffwwX7gMyn-2Hz9M6WFWl4CIomEMLz42R1xTDpZn33sPQAL7FMbqFf2ZqF_t66wO1tbqG8dOrVw6H1mI1lb83MTBgR8AujEwpZon2TGA8gAgYHCC6943Zag061f6UELbw3QdSIHeaxlus-zvkI11WSKPl_HBZBZGqWF78YISPNvJeGQwcYk__CBD-mW7THwsGrdpnU7rEulCkQl_hXCUPysK_05-c1mn3qst4bRQ',
  q: 'xZKlAjIapudEBlymNhhO_Ptq70XVDucV2RULYxFHlN72XGe8MELS8zzq9iEp2KzTIUPiiIuhyFTDjnqcQFTgMlFI9pDvx_OAsJoTld_pSTaTnxqJBfWWEjtPKFWVZbM7q2BNRLtZs_HWePnZIquCXpV0DLT6ilzTSPt0OUrdQafQe9x5_jgosrcvNszG6mpIV91OiE_p0WosD76eVdg6LzM_yUvcaWGVL9SmB0dWKdixBnIIPqUGESB1XAyJPpf4yYdC-KJx3znn2hXMFPgsEGqr63sRejSbnOa56VmMGIBCdM9NaIDNkuc-GnTnJ85LpxVxF2I-dOVuQEJy2GWTQw',
  dp: 'uGmzyyLrBOYPGQHJqVaJJ_IC953otwxAesS9lkx1hu1doz-shCdq4_DGVBAmauxh77ZFYRShiullkVVHh7Ivw6_rpgewSdsXNfqIIJGNRiRRpa25qflWpcZz-T8gBptf2gkL8W_JMKOqGmF0LWzVutmL1pHBwncttbOlaZi3Xz6qk-DpRL9kd9pBk-74eMLvBH60yIwYPLEjxAAbnj13m3fOD8bTkWQSQ05igZEU4uThhEzS8VLzxPv1VAlr_BPtD-YcETBxsddXKP_3O2mvSOuwLFhCJC9M3Cx7jSe8_mSVgDvjhm-wM-n8FXoYg4IurSK__6E104qcG4IMOPO2XQ',
  dq: 'VbOCuC0buoJe05Ok1Zo9yScV_6x--vPqWjvysIpyTnVY0ER_MUALWU93bER-bmqpOqjDvw8yoj-ChG9TD-TBS5JO4AWGvWk2zWRIUp7KBuQRrNZJ0bfx3P61G33kTDUvEOu5GLNb-d5RdjCKq6tR5c1WhZyLgTE6xVGt3JxI1Y4BtXixwkCCBuPHKzIwpsZrkxGAW0iu2BQCAOJitEITGx5T8PFjLqMRn6nSSx36ljRUtcMJKINU2mEGB2O4tNofJOvzdP6h_n6Tv9nsqLvuAUEESiUcM7JWPf0nb71UM9yO9zRlE4uroKmGGtvS2UV3M4btg4MuLG7JID6yqoOFGQ',
  qi: 'vk-THyk1-tcjtbirHnj883iqTGgs_gMjRE1exsHvxITCPfGf6nQ2GSyoURvTeBNxK3p1Qo0-Y2PNIOyjdcTMAR2Cl1YBhaZ6yfhh2Ys0aVPoFrWNl8f1U7POKOCmz1i1Luh2n2PnvquiJO20S549q5fVx6cDx9jrpu3DXuBIn_Sip2ezpln45u24bjxiE-UFdoRNDjkFnhxvEgfxpiR15yf8U6PUZlRjA_fWhWrv4mFxL3cZ26xw9b0b72AFQpWBFkN1nZ45Chg9E58gnvj8nE0yUymJZ6IqD0VEHkTQU0L_kChlxQhdwlsBgZyRm9Mx6dqGtXFJFmXBT4gwmJuWdA'
}

export function readResultRelay(params) {
  const { results, createDataItemSigner } = setupRelay(wallet) 
  params = {signer: createDataItemSigner(), ...params}
  return fromPromise(() =>
    new Promise((resolve) => setTimeout(() => resolve(params), 500))
  )()
    
    .chain(fromPromise(() => results(params)))
    .bichain(fromPromise(() =>
      new Promise((resolve, reject) => setTimeout(() => reject(params), 500))
    ),
      Resolved
    )
}

export function dryrunRelay({ processId, wallet, tags, data }, spinnner) {
  const { dryrun, createDataItemSigner } = setupRelay(wallet)
  return fromPromise(() =>
    arweave.wallets.jwkToAddress(wallet).then(Owner =>
      dryrun({ process: processId, Owner, signer: createDataItemSigner(), tags, data })
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
    new Promise((resolve) => setTimeout(() => { console.log('calling message'); resolve() }, 500))
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
 

  tags = tags.concat([{ name: 'aos-Version', value: pkg.version }])
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
    const signer = setupRelay(wallet).createDataItemSigner()
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

        const results = await setupRelay({}).results({signer, ...params})

        let edges = uniqBy(prop('cursor'))(results.edges.filter(function (e) {
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



  ct = await cron.schedule('*/2 * * * * *', printLive)
  return ct
}