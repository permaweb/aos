import readline from 'readline'
import minimist from 'minimist'
import { of, fromPromise, Rejected, Resolved } from 'hyper-async'
import { evaluate } from './evaluate.js'
import { register } from './register.js'
import { getWallet, getWalletFromArgs } from './services/wallets.js'
import { address } from './services/address.js'
import { spawnProcess } from './services/spawn-process.js'
import { gql } from './services/gql.js'
import { sendMessage } from './services/send-message.js'
import { readResult } from './services/read-result.js'
import { monitorProcess } from './services/monitor-process.js'
import { unmonitorProcess } from './services/unmonitor-process.js'
import { live, printLive } from './services/live.js'

import ora from 'ora'
import chalk from 'chalk'
import { splash } from './services/splash.js'
import { checkForUpdate, installUpdate, version } from './services/version.js'
import { load } from './commands/load.js'
import { monitor } from './commands/monitor.js'
import { checkLoadArgs } from './services/loading-files.js'
import { unmonitor } from './commands/unmonitor.js'
import { blueprints } from './services/blueprints.js'
import { loadBlueprint } from './commands/blueprints.js'
import { help, replHelp } from './services/help.js'
import { list } from './services/list.js'

const argv = minimist(process.argv.slice(2))

globalThis.alerts = {}
// make prompt global :(
globalThis.prompt = "aos> "

if (argv['get-blueprints']) {
  blueprints(argv['get-blueprints'])
  process.exit(0)
}

if (argv['help']) {
  help()
  process.exit(0)
}

if (argv['dev']) {
  console.log('*** DEV ENVIRONMENT ***')
  process.env.SCHEDULER = 'TZ7o7SIZ06ZEJ14lXwVtng1EtSx60QkPy-kh-kdAXog'
  process.env.CU_URL = 'https://ao-cu-router-1.onrender.com'
  process.env.MU_URL = 'https://ao-mu-router-1.onrender.com'

  console.log('CU', process.env.CU_URL)
  console.log('MU', process.env.MU_URL)
  console.log('SU', process.env.SCHEDULER)
}

if (argv['version']) {
  version()
  process.exit(0)
}

let cron = null
let history = []

splash()

of()
  .chain(fromPromise(() => argv.wallet ? getWalletFromArgs(argv.wallet) : getWallet()))
  .chain(jwk => {
    // handle list option, need jwk in order to do it.
    if (argv['list']) {
      return list(jwk, { address, gql }).chain(Rejected)
    }
    return Resolved(jwk)
  })
  .chain(jwk => register(jwk, { address, spawnProcess, gql })
    .map(id => ({ jwk, id }))
  )
  .toPromise()
  .then(async ({ jwk, id }) => {

    let editorMode = false
    let editorData = ""

    if (!id) {
      console.error(chalk.red("Error! Could not find Process ID"))
      process.exit(0)
    }
    version(id)

    // check for update and install if needed
    const update = await checkForUpdate()
    if (update.available && !process.env.DEBUG) {
      await installUpdate(update)
    }

    if (process.env.DEBUG) console.time(chalk.gray('connecting'))
    globalThis.prompt = await connect(jwk, id)
    if (process.env.DEBUG) console.timeEnd(chalk.gray('connecting'))
    // check loading files flag
    await handleLoadArgs(jwk, id)

    cron = await live(id)

    async function repl() {

      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
        terminal: true,
        history: history,
        historySize: 100
      });

      rl.on('history', e => {
        history.concat(e)
      })

      rl.question(editorMode ? "" : globalThis.prompt, async function (line) {
        if (line.trim() == '') {
          console.log(undefined)
          rl.close()
          repl()
          return;
        }

        if (!editorMode && line == ".help") {
          replHelp()
          rl.close()
          repl()
          return
        }

        if (!editorMode && line == ".live") {
          printLive()
          rl.close()
          repl()
          return
        }
        if (!editorMode && line == ".monitor") {
          const result = await monitor(jwk, id, { monitorProcess })
          console.log(result)
          rl.close()
          repl()
          return;
        }

        if (!editorMode && line == ".unmonitor") {
          const result = await unmonitor(jwk, id, { unmonitorProcess }).catch(err => chalk.gray('⚡️ monitor not found!'))
          console.log(result)
          rl.close()
          repl()
          return;
        }

        if (/^\.load-blueprint/.test(line)) {
          try { line = loadBlueprint(line) }
          catch (e) {
            console.log(e.message)
            rl.close()
            repl()
            return;
          }
        }

        if (/^\.load/.test(line)) {
          try { line = load(line) }
          catch (e) {
            console.log(e.message)
            rl.close()
            repl()
            return;
          }
        }

        if (line === ".editor") {
          console.log("<editor mode> use '.done' to submit or '.cancel' to cancel")
          editorMode = true;

          rl.close()
          repl()

          return;
        }

        if (editorMode && line === ".done") {
          line = editorData
          editorData = ""
          editorMode = false;

        }

        if (editorMode && line === ".cancel") {
          editorData = ""
          editorMode = false;

          cron.start()
          rl.close()
          repl()

          return;
        }

        if (editorMode) {
          editorData += line + '\n'

          rl.close()
          repl()

          return;
        }

        if (line === ".exit") {
          cron.stop();
          console.log("Exiting...");
          rl.close();
          return;
        }

        const spinner = ora({
          spinner: 'dots',
          suffixText: ``
        })

        if (process.env.DEBUG) console.time(chalk.gray('elapsed'))
        spinner.start();
        spinner.suffixText = chalk.gray("[Signing message and sequencing...]")

        printLive()
        // create message and publish to ao
        const result = await evaluate(line, id, jwk, { sendMessage, readResult }, spinner)
          .catch(err => ({ Output: JSON.stringify({ data: { output: err.message } }) }))
        const output = result.Output //JSON.parse(result.Output ? result.Output : '{"data": { "output": "error: could not parse result."}}')

        // log output
        spinner.stop()
        if (result.Error) {
          console.log(chalk.red(result.Error))
        } else {
          console.log(output.data?.output)
        }

        if (process.env.DEBUG) {
          console.log("\n")
          console.timeEnd(chalk.gray('elapsed'))
          console.log("\n")
        }

        if (cron) {
          cron.start()
        }
        // set prompt
        globalThis.prompt = output.data?.prompt ? output.data?.prompt : globalThis.prompt
        rl.close()
        repl()
      })
    }

    repl()

  })
  .catch(e => {
    console.log(e)
  })

async function connect(jwk, id) {
  const spinner = ora({
    spinner: 'dots',
    suffixText: ``
  })

  spinner.start();
  spinner.suffixText = chalk.gray("[Connecting to Process...]")

  // need to check if a process is registered or create a process
  let promptResult = await evaluate('"Loading..."', id, jwk, { sendMessage, readResult }, spinner)

  spinner.stop();
  return promptResult?.Output?.data?.prompt
}

async function handleLoadArgs(jwk, id) {
  const loadCode = checkLoadArgs().map(f => `.load ${f}`).map(load).join('\n')
  if (loadCode) {
    const spinner = ora({
      spinner: 'dots',
      suffixText: ``
    })
    spinner.start()
    spinner.suffixText = chalk.gray("[Signing message and sequencing...]")
    await evaluate(loadCode, id, jwk, { sendMessage, readResult }, spinner)
      .catch(err => ({ Output: JSON.stringify({ data: { output: err.message } }) }))
    spinner.stop()
  }
}