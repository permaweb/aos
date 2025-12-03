import './services/proxy.js'
import './services/dev.js'
import readline from 'readline'
import minimist from 'minimist'
import ora from 'ora'
import { chalk } from './utils/colors.js'
import path from 'path'
import * as url from 'url'
import process from 'node:process'
import { shouldShowSplash, shouldSuppressVersionBanner } from './services/process-type.js'

// Actions
import { evaluate } from './evaluate.js'
import { register } from './register.js'
import { dryEval } from './dry-eval.js'

// Services
import { getWallet, getWalletFromArgs } from './services/wallets.js'
import { address, isAddress } from './services/address.js'
import * as connectSvc from './services/connect.js'
import * as mainnetSvc from './services/mainnet.js'
import { blueprints } from './services/blueprints.js'
import { gql } from './services/gql.js'
import { splash } from './services/splash.js'
import { checkForUpdate, installUpdate, version } from './services/version.js'
import { getErrorOrigin, outputError, parseError } from './services/errors.js'
import { getPkg } from './services/get-pkg.js'

// Commands
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
import { config } from './config.js'
import { printWithFormat } from './utils/print.js'

const argv = minimist(process.argv.slice(2))
const splashEnabled = shouldShowSplash(argv)
const suppressVersionBanner = shouldSuppressVersionBanner(argv)

let dryRunMode = false
let luaData = ''

let {
  spawnProcess,
  sendMessage,
  readResult,
  monitorProcess,
  unmonitorProcess,
  live,
  printLive,
  dryrun
} = connectSvc

let {
  spawnProcessMainnet,
  sendMessageMainnet,
  readResultMainnet,
  liveMainnet,
  printLiveMainnet,
  handleNodeTopup
} = mainnetSvc

if (!process.stdin.isTTY) {
  const onData = chunk => {
    luaData = luaData + chunk
  }
  process.stdin.on('data', onData)
}

globalThis.alerts = {}
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
    process.stdout.write(
      '\n' + '\u001b[0G' + chalk.green('Watching: ') + chalk.blue(argv.watch) + '\n'
    )
    cron = res
  })
}

// Mainnet mode is the default behavior unless --legacy flag is used
if (!argv['legacy']) {
  try {
    // Use --url flag if provided, otherwise use DEFAULT_HB_NODE from config
    process.env.AO_URL = argv['url'] || config.urls.DEFAULT_HB_NODE

    // Get scheduler if in mainnet mode
    process.env.SCHEDULER = process.env.SCHEDULER ?? config.addresses.SCHEDULER_MAINNET

    // Replace services to use mainnet service
    sendMessage = sendMessageMainnet
    spawnProcess = spawnProcessMainnet
    readResult = () => null
    live = liveMainnet
    printLive = printLiveMainnet
    dryrun = () => null
  } catch (e) {
    console.error(e)
    console.error(chalk.red('Error connecting to ' + (argv['url'] || config.urls.DEFAULT_HB_NODE)))
    process.exit(1)
  }
}

// Support --mainnet flag for backwards compatibility
if (argv['mainnet']) {
  if (typeof argv['mainnet'] !== 'string' || argv['mainnet'].trim() === '') {
    console.error(chalk.red('The --mainnet flag requires a value, e.g. --mainnet <url>'))
    process.exit(1)
  }

  try {
    process.env.AO_URL = argv['mainnet']

    // Get scheduler if in mainnet mode
    process.env.SCHEDULER = process.env.SCHEDULER ?? config.addresses.SCHEDULER_MAINNET

    // Replace services to use mainnet service
    sendMessage = sendMessageMainnet
    spawnProcess = spawnProcessMainnet
    readResult = () => null
    live = liveMainnet
    printLive = printLiveMainnet
    dryrun = () => null
  } catch (e) {
    console.error(e)
    console.error(chalk.red('Error connecting to ' + argv['mainnet']))
    process.exit(1)
  }
}

if (argv['gateway-url']) {
  process.env.GATEWAY_URL = argv['gateway-url']
}

if (argv['cu-url']) {
  process.env.CU_URL = argv['cu-url']
}

if (argv['mu-url']) {
  process.env.MU_URL = argv['mu-url']
}

if (argv['authority']) {
  process.env.AUTHORITY = argv['authority']
}

if (argv['scheduler']) {
  process.env.SCHEDULER = argv['scheduler']
}

if (splashEnabled && !suppressVersionBanner) {
  splash({
    mainnetUrl: argv['mainnet'] || (!argv['legacy'] ? (argv['url'] || config.urls.DEFAULT_HB_NODE) : undefined),
    gatewayUrl: argv['gateway-url'],
    cuUrl: argv['cu-url'],
    muUrl: argv['mu-url'],
    authority: argv['authority'],
    scheduler: (argv['scheduler'] ?? config.addresses.SCHEDULER_MAINNET) && !argv['legacy'] ? config.addresses.SCHEDULER_MAINNET : undefined,
    legacy: argv['legacy'],
  })
}

async function runProcess() {
  if (!argv.watch) {
    try {
      // Get wallet
      const jwk = argv.wallet ? await getWalletFromArgs(argv.wallet) : await getWallet()

      if (argv.list) {
        await list(jwk, { address, gql })
        process.exit(0)
      }

      // Make wallet available to services if relay mode or mainnet mode (default)
      if (argv['mainnet'] || !argv['legacy']) {
        process.env.WALLET = JSON.stringify(jwk)
      }

      // Register/find process
      const { id, variant } = await register(jwk, { address, isAddress, spawnProcess, gql, spawnProcessMainnet })

      // Continue with the process
      {
        let editorMode = false
        let editorData = ''
        const history = readHistory(id)

        // This can be improved, but for now if ao-url is set
        // We will use hyper mode
        if (process.env.AO_URL !== 'undefined') {
          process.env.WALLET = JSON.stringify(jwk)
          sendMessage = sendMessageMainnet
          readResult = readResultMainnet
          live = liveMainnet
          printLive = printLiveMainnet
        }

        if ((argv.mainnet || !argv.legacy) && argv.topup) {
          await handleNodeTopup(jwk, false)
        }

        if (!argv.run && luaData.length > 0 && argv.load) {
          const spinner = ora({
            spinner: 'dots',
            suffixText: ''
          })

          spinner.start()
          spinner.suffixText = chalk.gray('[Connecting To Process...]')
          const result = await evaluate(luaData, id, jwk, { sendMessage, readResult }, spinner)

          spinner.stop()

          if (result.Output?.data) {
            printWithFormat(result.Output?.data)
          }
          process.exit(0)
        }

        if (!id) {
          console.error(chalk.red('Error! Could not find process ID.'))
          process.exit(0)
        }

        const variantDisplay = variant ? ` ${chalk.gray(`${variant}`)}` : ''
        printWithFormat(`${chalk.white('Your AOS Process:')} ${chalk.green(id)}${variantDisplay}`)

        // Kick start monitor if monitor option
        if (argv.monitor) {
          const result = await monitor(jwk, id, { monitorProcess })
          printWithFormat(chalk.green(result))
        }

        // Check for update and install if needed
        const update = await checkForUpdate()
        if (update.available && !process.env.DEBUG) {
          const __dirname = url.fileURLToPath(new URL('.', import.meta.url))

          await installUpdate(update, path.join(__dirname, '../'))
        }

        if (argv.run) {
          if (!argv._.length) {
            console.error(chalk.red('The --run flag requires a process name or address.'))
            process.exit(1)
          }

          const spinner = ora({
            spinner: 'dots',
            suffixText: ''
          })

          spinner.start()
          spinner.suffixText = chalk.gray('[Connecting To Process...]')

          const { ok } = await evaluateAndPrint({
            line: argv.run,
            id,
            jwk,
            spinner,
            dryRunMode: argv['dry-run'] || argv.dryrun
          })

          process.exit(ok ? 0 : 1)
        }

        if (process.env.DEBUG) console.time(chalk.gray('Connecting'))

        globalThis.prompt = await connect(jwk, id, luaData)
        if (process.env.DEBUG) console.timeEnd(chalk.gray('Connecting'))

        // Check loading files flag
        await handleLoadArgs(jwk, id)

        cron = await live(id)
        cron.start()

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

        // Make readline interface globally available for printLiveMainnet
        globalThis.rl = rl

        globalThis.setPrompt = p => {
          rl.setPrompt(p)
        }

        // Override prompt
        const originalPrompt = rl.prompt.bind(rl)
        rl.prompt = (preserveCursor) => {
          originalPrompt(preserveCursor)
        }

        rl.on('history', e => {
          history.concat(e)
        })

        rl.setPrompt(globalThis.prompt)
        if (!editorMode) rl.prompt(true)

        rl.on('line', async line => {
          // If empty input, just redisplay prompt
          if (!editorMode && line.trim() === '') {
            printWithFormat()
            rl.prompt(true)
            return
          }

          // Calculate how many lines the prompt + input took (accounting for line wrapping)
          const terminalWidth = process.stdout.columns || 80
          const promptLength = rl.getPrompt().replace(/\x1b\[[0-9;]*m/g, '').length
          const totalLength = promptLength + line.length
          const linesUsed = Math.ceil(totalLength / terminalWidth)

          // Clear all the lines (prompt + wrapped lines)
          for (let i = 0; i < linesUsed; i++) {
            process.stdout.write('\x1b[1A\r\x1b[K') // Move up and clear line
          }

          // Log user input
          printWithFormat(chalk.gray(line))

          if (!editorMode && line === '.help') {
            replHelp()
            rl.prompt(true)
            return
          }

          // Continue live
          if (!editorMode && line === '.live') {
            printWithFormat('=== Starting Live Feed ===')
            cron.start()
            rl.prompt(true)
            return
          }

          // Pause live
          if (!editorMode && line === '.pause') {
            printWithFormat('=== Pausing Live Feed ===')
            cron.stop()
            rl.prompt(true)
            return
          }

          if (!editorMode && line === '.dryrun') {
            dryRunMode = !dryRunMode
            if (dryRunMode) {
              printWithFormat(chalk.green('Dryrun Mode Engaged'))
              rl.setPrompt((dryRunMode ? chalk.red('*') : '') + globalThis.prompt)
            } else {
              printWithFormat(chalk.red('Dryrun Mode Disengaged'))
              rl.setPrompt(globalThis.prompt.replace('*', ''))
            }
            rl.prompt(true)
            return
          }

          if (!editorMode && line === '.monitor') {
            const result = await monitor(jwk, id, { monitorProcess }).catch(_ =>
              chalk.gray('Could not monitor process!')
            )
            printWithFormat(chalk.green(result))
            rl.prompt(true)
            return
          }

          if (!editorMode && line === '.unmonitor') {
            const result = await unmonitor(jwk, id, { unmonitorProcess }).catch(_ =>
              chalk.gray('Monitor not found!')
            )
            printWithFormat(chalk.green(result))
            rl.prompt(true)
            return
          }

          if (/^\.load-blueprint/.test(line)) {
            try {
              line = loadBlueprint(line)
            } catch (e) {
              printWithFormat(e.message)
              rl.prompt(true)
              return
            }
          }

          // Modules loaded
          /** @type {Module[]} */
          let loadedModules = []
          if (/^\.load/.test(line)) {
            try {
              ;[line, loadedModules] = load(line)
            } catch (e) {
              printWithFormat(e.message)
              rl.prompt(true)
              return
            }
          }

          if (line === '.editor') {
            printWithFormat("<editor mode> use '.done' to submit or '.cancel' to cancel")
            editorMode = true
            rl.setPrompt('')
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
            printWithFormat(editorData)
            editorData = ''
            editorMode = false
            rl.setPrompt((dryRunMode ? chalk.red('*') : '') + globalThis.prompt)
            rl.prompt(true)
            return
          }

          if (editorMode && line === '.cancel') {
            editorData = ''
            editorMode = false
            rl.setPrompt(dryRunMode ? chalk.red('*') : '' + globalThis.prompt)
            rl.prompt(true)

            return
          }

          if (editorMode) {
            editorData += line + '\n'
            rl.prompt(true)

            return
          }

          if (line === '.pad') {
            rl.pause()
            pad(id, async (err, content) => {
              if (!err) {
                await doEvaluate(content, id, jwk, spinner, rl, loadedModules, dryRunMode)
              }
              rl.resume()
              rl.prompt(true)
            })
            return
          }

          if (line === '.exit') {
            cron.stop()
            printWithFormat('Exiting...')
            rl.close()
            process.exit(0)
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
          rl.prompt(true)
        })

        process.on('SIGINT', function () {
          // Clear the line to hide ^C
          readline.clearLine(process.stdout, 0)
          readline.cursorTo(process.stdout, 0)

          // Save the input history when the user exits
          if (id) {
            writeHistory(id, history)
          }
          process.exit(0)
        })
      }
    } catch (e) {
      if (argv.list) {
        printWithFormat(e)
      } else {
        if (process.env.DEBUG) {
          printWithFormat(e)
        }
        if (argv.load) {
          printWithFormat(e.message)
        } else {
          printWithFormat(
            chalk.red(
              '\nAn Error occurred trying to contact your AOS process. Please check your access points, and if the problem persists contact support.'
            )
          )
          process.exit(1)
        }
      }
    }
  }
}

runProcess()

async function connect(jwk, id) {
  const spinner = ora({
    spinner: 'dots',
    suffixText: ''
  })

  spinner.start()
  spinner.suffixText = chalk.gray('[Connecting To Process...]')

  let promptResult = undefined
  let _prompt = undefined
  // Need to check if a process is registered or create a process
  promptResult = await evaluate(
    `require('.process')._version`,
    id,
    jwk,
    { sendMessage, readResult },
    spinner,
    true
  )
  _prompt = promptResult?.Output?.prompt || promptResult?.Output?.data?.prompt
  for (let i = 0; i < 50; i++) {
    if (_prompt === undefined) {
      if (i === 0) {
        spinner.suffixText = chalk.gray('[Connecting To Process...]')
      } else {
        spinner.suffixText = chalk.red('[Connecting To Process...]')
      }
      promptResult = await evaluate(
        `require('.process')._version`,
        id,
        jwk,
        { sendMessage, readResult },
        spinner
      )
      _prompt = promptResult?.Output?.prompt || promptResult?.Output?.data?.prompt
    } else {
      break
    }
  }
  spinner.stop()
  if (_prompt === undefined) {
    printWithFormat('Could not connect to process! Exiting...')
    process.exit(1)
  }
  const aosVersion = getPkg().aos.version
  if (promptResult.Output.data?.output !== aosVersion && promptResult.Output.data !== aosVersion) {
    // Only prompt for updates if version is not eq to dev
    if (promptResult.Output.data !== 'dev') {
      printWithFormat(chalk.green('A new AOS update is available. run [.update] to install.'))
    }
  }
  return _prompt
}

async function handleLoadArgs(jwk, id) {
  const loadCode = checkLoadArgs()
    .map(f => `.load ${f}`)
    .map(line => load(line)[0])
    .join('\n')
  if (loadCode) {
    const spinner = ora({
      spinner: 'dots',
      suffixText: ''
    })
    spinner.start()
    spinner.suffixText = chalk.gray('[Signing Message and Sequencing...]')
    await evaluate(loadCode, id, jwk, { sendMessage, readResult }, spinner).catch(err => ({
      Output: JSON.stringify({ data: { output: err.message } })
    }))

    spinner.stop()
  }
}

async function evaluateAndPrint({
  line,
  id,
  jwk,
  spinner,
  loadedModules = [],
  dryRunMode = false,
  setPrompt
}) {
  if (spinner) {
    spinner.start()
    spinner.suffixText = chalk.gray('[Dispatching Message...]')
  }

  const evaluator = dryRunMode
    ? () => dryEval(line, id, jwk, { dryrun }, spinner)
    : () => evaluate(line, id, jwk, { sendMessage, readResult }, spinner)

  const result = await evaluator().catch(err => ({
    Output: JSON.stringify({ data: { output: err.message } })
  }))

  if (spinner) {
    spinner.stop()
  }

  const handled = handleEvaluationResult({
    line,
    result,
    loadedModules,
    dryRunMode,
    setPrompt
  })

  return { ...handled, result }
}

function handleEvaluationResult({ line, result, loadedModules, dryRunMode, setPrompt }) {
  const output = result?.Output
  const errorPayload = result?.Error || result?.error

  if (errorPayload) {
    const error = parseError(errorPayload)
    if (error) {
      const errorOrigin = getErrorOrigin(loadedModules, error.lineNumber)
      outputError(line, error, errorOrigin)
    } else {
      printWithFormat(chalk.red(errorPayload))
    }

    return { ok: false }
  }

  if (output?.data) {
    if (Object.prototype.hasOwnProperty.call(output.data, 'output')) {
      printWithFormat(output.data.output)
    } else if (Object.prototype.hasOwnProperty.call(output.data, 'prompt')) {
      printWithFormat('')
    } else {
      printWithFormat(output.data)
    }

    const nextPrompt = Object.prototype.hasOwnProperty.call(output.data, 'prompt')
      ? output.data.prompt
      : output.prompt

    if (nextPrompt) {
      globalThis.prompt = nextPrompt
      if (typeof setPrompt === 'function') {
        setPrompt(dryRunMode ? chalk.red('*') + nextPrompt : nextPrompt)
      }
    }

    return { ok: true, prompt: globalThis.prompt }
  }

  if (!output) {
    printWithFormat(chalk.red('An unknown error occurred.'))
    return { ok: false }
  }

  if (typeof output === 'string') {
    printWithFormat(output)
    return { ok: true, prompt: globalThis.prompt }
  }

  printWithFormat(output)
  return { ok: true, prompt: globalThis.prompt }
}

async function doEvaluate(line, id, jwk, spinner, rl, loadedModules, dryRunMode) {
  await evaluateAndPrint({
    line,
    id,
    jwk,
    spinner,
    loadedModules,
    dryRunMode,
    setPrompt: prompt => rl.setPrompt(prompt)
  })
  if (dryRunMode) {
    rl.setPrompt(chalk.red('*') + globalThis.prompt)
  }
}
