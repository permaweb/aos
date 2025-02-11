import './services/proxy.js'
import './services/dev.js'
import readline from 'readline'
import minimist from 'minimist'
import ora from 'ora'
import chalk from 'chalk'
import path from 'path'
import * as url from 'url'
import process from 'node:process'

import { of, fromPromise, Rejected, Resolved } from 'hyper-async'

// actions
import { evaluate } from './evaluate.js'
import { register } from './register.js'
import { dryEval } from './dry-eval.js'

// services
import { getWallet, getWalletFromArgs } from './services/wallets.js'
import { address, isAddress } from './services/address.js'
import * as connectSvc from './services/connect.js'
import * as relaySvc from './services/relay.js'
import * as mainnetSvc from './services/mainnet.js'
import { blueprints } from './services/blueprints.js'
import { gql } from './services/gql.js'
import { splash } from './services/splash.js'
import { checkForUpdate, installUpdate, version } from './services/version.js'
import { getErrorOrigin, outputError, parseError } from './services/errors.js'
import { getPkg } from './services/get-pkg.js'

// commands
import { load } from './commands/load.js'
import { monitor } from './commands/monitor.js'
import { checkLoadArgs } from './services/loading-files.js'
import { unmonitor } from './commands/unmonitor.js'
import { loadBlueprint } from './commands/blueprints.js'
import { help, replHelp } from './services/help.js'
import { list } from './services/list.js'
import * as os from './commands/os.js'
import { readHistory, writeHistory } from './services/history-service.js'
import { pad } from './commands/pad.js'

const argv = minimist(process.argv.slice(2))

let dryRunMode = false
let luaData = ''
let relayMode = false

let {
  spawnProcess, sendMessage, readResult, monitorProcess, unmonitorProcess, live, printLive, dryrun
} = connectSvc

let {
  spawnProcessRelay, sendMessageRelay, readResultRelay,
  monitorProcessRelay, unmonitorProcessRelay, liveRelay, printLiveRelay,
  dryrunRelay, handleRelayTopup
} = relaySvc

let {
  spawnProcessMainnet, sendMessageMainnet, readResultMainnet,
  monitorProcessMainnet, unmonitorProcessMainnet, liveMainnet, printLiveMainnet,
  dryrunMainnet
} = mainnetSvc

if (!process.stdin.isTTY) {
  const onData = chunk => {
    luaData = luaData + chunk
  }
  process.stdin.on('data', onData)
  // process.stdin.on('end', onEnd)
}

globalThis.alerts = {}
// make prompt global :(
globalThis.prompt = 'aos> '

if (argv['get-blueprints']) {
  blueprints(argv['get-blueprints'])
  process.exit(0)
}

if (argv.help) {
  help()
  process.exit(0)
}

if (argv.version) {
  version()
  process.exit(0)
}

if (argv.sqlite) {
  process.env.AOS_MODULE = getPkg().aos.sqlite
}

/**
 * A module can be specified when spawning a process using AOS
 * that value can be the id of the module, or a colloquial 'name' for the module
 *
 * this code assumes that the provided value is a TXid if the length matches what a TXid should be
 * otherwise, we set the env variable AOS_MODULE_NAME
 *
 * https://github.com/permaweb/aos/issues/310
 */
if (argv.module) {
  if (argv.module.length === 43) {
    process.env.AOS_MODULE = argv.module
  } else {
    process.env.AOS_MODULE_NAME = argv.module
  }
}

let cron = null

if (argv.watch && argv.watch.length === 43) {
  live(argv.watch, true).then(res => {
    process.stdout.write('\n' + '\u001b[0G' + chalk.green('Watching: ') + chalk.blue(argv.watch) + '\n')
    cron = res
  })
}

splash()

if (argv['relay']) {
  console.log(chalk.cyanBright('Using Relay: ') + chalk.cyan(argv['relay']))
  process.env.RELAY_URL = argv['relay']
  // replace services to use relay service
  sendMessage = sendMessageRelay
  spawnProcess = spawnProcessRelay
  readResult = readResultRelay
  monitorProcess = monitorProcessRelay
  unmonitorProcess = unmonitorProcessRelay
  live = liveRelay
  printLive = printLiveRelay
  dryrun = dryrunRelay

  relayMode = true
}
if (argv['mainnet']) {
  console.log(chalk.magentaBright('Using Mainnet: ') + chalk.magenta(argv['mainnet']))
  process.env.AO_URL = argv['mainnet']
  // get scheduler if in mainnetmode
  process.env.SCHEDULER = await fetch(`${process.env.AO_URL}/~meta@1.0/address`).then(res => res.text())
  // replace services to use mainnet service
  sendMessage = sendMessageMainnet
  spawnProcess = spawnProcessMainnet
  readResult = readResultMainnet
  monitorProcess = monitorProcessMainnet
  unmonitorProcess = unmonitorProcessMainnet
  live = liveMainnet
  printLive = printLiveMainnet
  dryrun = dryrunMainnet

  relayMode = true
}
if (argv['gateway-url']) {
  console.log(chalk.yellow('Using Gateway: ') + chalk.blue(argv['gateway-url']))
  process.env.GATEWAY_URL = argv['gateway-url']
}

if (argv['cu-url']) {
  console.log(chalk.yellow('Using CU: ') + chalk.blue(argv['cu-url']))
  process.env.CU_URL = argv['cu-url']
}

if (argv['mu-url']) {
  console.log(chalk.yellow('Using MU: ') + chalk.blue(argv['mu-url']))
  process.env.MU_URL = argv['mu-url']
}

async function runProcess() {
  if (!argv.watch) {
    of()
      .chain(fromPromise(() => argv.wallet ? getWalletFromArgs(argv.wallet) : getWallet()))
      .chain(jwk => {
        // make wallet available to services if relay mode
        if (argv['relay']) {
          process.env.WALLET = JSON.stringify(jwk)
        }
        // handle list option, need jwk in order to do it.
        if (argv.list) {
          return list(jwk, { address, gql }).chain(Rejected)
        }
        return Resolved(jwk)
      })
      .chain(jwk => register(jwk, { address, isAddress, spawnProcess, gql })
        .map(id => ({ jwk, id }))
      )
      .toPromise()
      .then(async ({ jwk, id }) => {
        let editorMode = false
        let editorData = ''

        const history = readHistory(id)

        if (luaData.length > 0 && argv.load) {
          const spinner = ora({
            spinner: 'dots',
            suffixText: ''
          })

          spinner.start()
          spinner.suffixText = chalk.gray('[Connecting to process...]')
          const result = await evaluate(luaData, id, jwk, { sendMessage, readResult }, spinner)

          spinner.stop()

          if (result.Output?.data) {
            console.log(result.Output?.data)
          }
          process.exit(0)
        }

        if (!id) {
          console.error(chalk.red('Error! Could not find process ID.'))
          process.exit(0)
        }
        version(id)

        // kick start monitor if monitor option
        if (argv.monitor) {
          const result = await monitor(jwk, id, { monitorProcess })
          console.log(chalk.green(result))
        }

        // check for update and install if needed
        const update = await checkForUpdate()
        if (update.available && !process.env.DEBUG) {
          const __dirname = url.fileURLToPath(new URL('.', import.meta.url))

          await installUpdate(update, path.join(__dirname, '../'))
        }

        if (process.env.DEBUG) console.time(chalk.gray('Connecting'))
        globalThis.prompt = await connect(jwk, id, luaData)
        if (process.env.DEBUG) console.timeEnd(chalk.gray('Connecting'))
        // check loading files flag
        await handleLoadArgs(jwk, id)

        cron = await live(id)

        const spinner = ora({
          spinner: 'dots',
          suffixText: '',
          discardStdin: false
        })

        const rl = readline.createInterface({
          input: process.stdin,
          output: process.stdout,
          terminal: true,
          history,
          historySize: 100,
          prompt: globalThis.prompt
        })
        globalThis.setPrompt = (p) => {
          rl.setPrompt(p)
        }

        // async function repl() {

        // process.stdin.on('keypress', (str, key) => {
        //   if (ct) {
        //     ct.stop()
        //   }
        // })

        rl.on('history', e => {
          history.concat(e)
        })

        // rl.question(editorMode ? "" : globalThis.prompt, async function (line) {
        rl.setPrompt(globalThis.prompt)
        if (!editorMode) rl.prompt(true)

        rl.on('line', async line => {
          if (!editorMode && line.trim() === '') {
            console.log(undefined)
            // rl.close()
            // repl()
            rl.prompt(true)
            return
          }

          if (!editorMode && line === '.help') {
            replHelp()
            // rl.close()
            // repl()
            rl.prompt(true)
            return
          }

          if (!editorMode && line === '.live') {
            // printLive()
            cron.start()
            // rl.close()
            // repl()
            rl.prompt(true)
            return
          }
          // pause live
          if (!editorMode && line === '.pause') {
            // pause live feed
            cron.stop()
            rl.prompt(true)
            return
          }

          if (!editorMode && line === '.dryrun') {
            dryRunMode = !dryRunMode
            if (dryRunMode) {
              console.log(chalk.green('dryrun mode engaged'))
              rl.setPrompt((dryRunMode ? chalk.red('*') : '') + globalThis.prompt)
            } else {
              console.log(chalk.red('dryrun mode disengaged'))
              rl.setPrompt(globalThis.prompt.replace('*', ''))
            }
            rl.prompt(true)
            return
          }

          if (!editorMode && line === '.monitor') {
            const result = await monitor(jwk, id, { monitorProcess }).catch(_ => chalk.gray('⚡️ could not monitor process!'))
            console.log(chalk.green(result))
            // rl.close()
            // repl()
            rl.prompt(true)
            return
          }

          if (!editorMode && line === '.unmonitor') {
            const result = await unmonitor(jwk, id, { unmonitorProcess }).catch(_ => chalk.gray('⚡️ monitor not found!'))
            console.log(chalk.green(result))
            // rl.close()
            // repl()
            rl.prompt(true)
            return
          }

          if (/^\.load-blueprint/.test(line)) {
            try { line = loadBlueprint(line) } catch (e) {
              console.log(e.message)
              // rl.close()
              // repl()
              rl.prompt(true)
              return
            }
          }

          // modules loaded
          /** @type {Module[]} */
          let loadedModules = []
          if (/^\.load/.test(line)) {
            try { [line, loadedModules] = load(line) } catch (e) {
              console.log(e.message)
              // rl.close()
              // repl()
              rl.prompt(true)
              return
            }
          }

          if (line === '.editor') {
            console.log("<editor mode> use '.done' to submit or '.cancel' to cancel")
            editorMode = true
            rl.setPrompt('')

            // rl.close()
            // repl()
            rl.prompt(true)

            return
          }

          if (editorMode && line === '.done') {
            line = editorData
            editorData = ''
            editorMode = false
            rl.setPrompt((dryRunMode ? chalk.red('*') : '') + globalThis.prompt)
          }

          if (editorMode && line === '.delete') {
            const lines = editorData.split('\n')
            lines.pop()
            lines.pop()
            editorData = lines.join('\n') + '\n'
            readline.moveCursor(process.stdout, 0, -1)
            readline.clearLine(process.stdout, 0)
            readline.cursorTo(process.stdout, 0)

            readline.moveCursor(process.stdout, 0, -1)
            readline.clearLine(process.stdout, 0)
            readline.cursorTo(process.stdout, 0)

            return
          }

          if (editorMode && line === '.print') {
            console.log(editorData)
            editorData = ''
            editorMode = false
            // rl.setPrompt(globalThis.prompt)
            rl.setPrompt((dryRunMode ? chalk.red('*') : '') + globalThis.prompt)
            rl.prompt(true)
            return
          }

          if (editorMode && line === '.cancel') {
            editorData = ''
            editorMode = false
            // rl.setPrompt(globalThis.prompt)
            rl.setPrompt(dryRunMode ? chalk.red('*') : '' + globalThis.prompt)

            // rl.close()
            // repl()
            rl.prompt(true)

            return
          }

          if (editorMode) {
            editorData += line + '\n'

            // rl.close()
            // repl()
            rl.prompt(true)

            return
          }

          if (line === '.pad') {
            rl.pause()
            pad(id, async (err, content) => {
              if (!err) {
                // console.log(content)
                await doEvaluate(content, id, jwk, spinner, rl, loadedModules, dryRunMode)
              }
              rl.resume()
              rl.prompt(true)
            })
            return
          }

          if (line === '.exit') {
            cron.stop()
            console.log('Exiting...')
            rl.close()
            return
          }

          if (line === '.update') {
            line = os.update()
          }

          if (process.env.DEBUG) console.time(chalk.gray('Elapsed'))
          printLive()

          await doEvaluate(line, id, jwk, spinner, rl, loadedModules, dryRunMode)

          if (process.env.DEBUG) {
            console.timeEnd(chalk.gray('Elapsed'))
          }

          if (cron) {
            cron.start()
          }

          // rl.close()
          // repl()
          rl.prompt(true)
        })

        process.on('SIGINT', function () {
          // save the input history when the user exits
          if (id) {
            writeHistory(id, history)
          }
          process.exit(0)
        })

        // }

        // repl()
      })
      .catch(async e => {
        if (argv.list) {
          console.log(e)
        } else {
          if (argv.relay) {
            let jwk;
            if (process.env.WALLET) {
              try {
                jwk = JSON.parse(process.env.WALLET);
              } catch (err) {
                console.error('Error parsing WALLET from environment:', err);
              }
            }

            try {
              const topupSuccess = await handleRelayTopup(jwk);
              if (topupSuccess) {
                return runProcess();
              }
            } catch (topupError) {
              console.error('Error handling relay topup:', topupError);
              process.exit(1);
            }
          }
          if (process.env.DEBUG) {
            console.log(e)
          }
          if (argv.load) {
            console.log(e.message)
          } else {
            console.log(e)
            console.log(chalk.red('\nAn Error occurred trying to contact your AOS process. Please check your access points, and if the problem persists contact support.'))
            process.exit(1)
          }
        }
      })
  }
}

runProcess()

async function connect(jwk, id) {
  const spinner = ora({
    spinner: 'dots',
    suffixText: ''
  })

  spinner.start()
  spinner.suffixText = chalk.gray('[Connecting to process...]')

  // need to check if a process is registered or create a process
  let promptResult = await evaluate("require('.process')._version", id, jwk, { sendMessage, readResult }, spinner)
  let _prompt = promptResult?.Output?.prompt || promptResult?.Output?.data?.prompt
  for (let i = 0; i < 50; i++) {
    if (_prompt === undefined) {
      spinner.suffixText = chalk.red('[Connecting to process....]')
      await new Promise(resolve => setTimeout(resolve, 500 * i))
      promptResult = await evaluate("require('.process')._version", id, jwk, { sendMessage, readResult }, spinner)
      // console.log({ promptResult })
      _prompt = promptResult?.Output?.prompt || promptResult?.Output?.data?.prompt
    } else {
      break
    }
  }
  spinner.stop()
  if (_prompt === undefined) {
    console.log('Could not connect to process! Exiting...')
    process.exit(1)
  }
  const aosVersion = getPkg().aos.version
  if (promptResult.Output.data?.output !== aosVersion && promptResult.Output.data !== aosVersion) {
    console.log(chalk.blue('A new AOS update is available. run [.update] to install.'))
  }
  return _prompt
}

async function handleLoadArgs(jwk, id) {
  const loadCode = checkLoadArgs().map(f => `.load ${f}`).map(line => load(line)[0]).join('\n')
  if (loadCode) {
    const spinner = ora({
      spinner: 'dots',
      suffixText: ''
    })
    spinner.start()
    spinner.suffixText = chalk.gray('[Signing message and sequencing...]')
    await evaluate(loadCode, id, jwk, { sendMessage, readResult }, spinner)
      .catch(err => ({ Output: JSON.stringify({ data: { output: err.message } }) }))

    spinner.stop()
  }
}

async function doEvaluate(line, id, jwk, spinner, rl, loadedModules, dryRunMode) {
  spinner.start()
  spinner.suffixText = chalk.gray('[Dispatching message...]')

  // create message and publish to ao
  let result = null
  if (dryRunMode) {
    result = await dryEval(line, id, jwk, { dryrun }, spinner)
      .catch(err => ({ Output: JSON.stringify({ data: { output: err.message } }) }))
  } else {
    result = await evaluate(line, id, jwk, { sendMessage, readResult }, spinner)
      .catch(err => ({ Output: JSON.stringify({ data: { output: err.message } }) }))
  }
  const output = result.Output // JSON.parse(result.Output ? result.Output : '{"data": { "output": "error: could not parse result."}}')
  // log output
  // console.log(output)
  spinner.stop()

  if (result?.Error || result?.error) {
    const error = parseError(result.Error || result.error)
    if (error) {
      // get what file the error comes from,
      // if the line was loaded
      const errorOrigin = getErrorOrigin(loadedModules, error.lineNumber)
      // print error
      outputError(line, error, errorOrigin)
    } else {
      console.log(chalk.red(result.Error || result.error))
    }
  } else {
    if (output?.data) {
      if (Object.prototype.hasOwnProperty.call(output.data, 'output')) {
        console.log(output.data.output)
      } else if (Object.prototype.hasOwnProperty.call(output.data, 'prompt')) {
        console.log('')
      } else {
        console.log(output.data)
      }
      if (Object.prototype.hasOwnProperty.call(output.data, 'prompt')) {
        globalThis.prompt = output.data.prompt ? output.data.prompt : globalThis.prompt
      } else {
        globalThis.prompt = output.prompt ? output.prompt : globalThis.prompt
      }
      rl.setPrompt((dryRunMode ? chalk.red('*') : '') + globalThis.prompt)
      // rl.setPrompt(globalThis.prompt)
    } else {
      if (!output) {
        console.log(chalk.red('An unknown error occurred.'))
      }
    }
  }
}
