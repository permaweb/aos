import readline from 'readline'
import minimist from 'minimist'
import { of, fromPromise } from 'hyper-async'
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

import ora from 'ora'
import chalk from 'chalk'
import { splash } from './services/splash.js'
import { version } from './services/version.js'
import { load } from './commands/load.js'
import { monitor } from './commands/monitor.js'
import { checkLoadArgs } from './services/loading-files.js'
import { unmonitor } from './commands/unmonitor.js'
import { blueprints } from './services/blueprints.js'

const argv = minimist(process.argv.slice(2))

if (argv['blueprints']) {
  blueprints()
  process.exit(0)
}

let history = []

splash()

of()
  .chain(fromPromise(() => argv.wallet ? getWalletFromArgs(argv.wallet) : getWallet()))
  .chain(jwk => register(jwk, { address, spawnProcess, gql })
    .map(id => ({ jwk, id }))
  )
  .toPromise()
  .then(async ({ jwk, id }) => {
    if (!id) {
      console.error(chalk.red("Error! Could not find Process ID"))
      process.exit(0)
    }
    version(id)
    let prompt = await connect(jwk, id)
    // check loading files flag
    await handleLoadArgs(jwk, id)

    let editorMode = false
    let editorData = ""

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

      rl.question(editorMode ? "" : prompt, async function (line) {
        if (line.trim() == '') {
          console.log(undefined)
          rl.close()
          repl()
          return;
        }

        if (!editorMode && line == ".monitor") {
          const result = await monitor(jwk, id, { monitorProcess })
          console.log(result)
          rl.close()
          repl()
          return;
        }

        if (!editorMode && line == ".unmonitor") {
          const result = await unmonitor(jwk, id, { unmonitorProcess })
          console.log(result)
          rl.close()
          repl()
          return;
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
          console.log("Exiting...");
          rl.close();
          return;
        }

        const spinner = ora({
          spinner: 'dots',
          suffixText: ``
        })

        spinner.start();
        spinner.suffixText = chalk.gray("[Signing message and sequencing...]")

        // create message and publish to ao
        const result = await evaluate(line, id, jwk, { sendMessage, readResult }, spinner)
          .catch(err => ({ Output: JSON.stringify({ data: { output: err.message } }) }))
        const output = result.Output //JSON.parse(result.Output ? result.Output : '{"data": { "output": "error: could not parse result."}}')
        if (process.env.DEBUG) {
          console.log({id})
          console.log({result})
        }
        // log output
        spinner.stop()
        if (result.Error) {
          console.log(chalk.red(result.Error))
        } else {
          console.log(output.data?.output)
        }

        // set prompt
        prompt = output.data?.prompt ? output.data?.prompt : prompt
        rl.close()
        repl()
      })
    }

    repl()

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