import readline from 'readline'
import path from 'path'
import fs from 'fs'
import { of, fromPromise } from 'hyper-async'
import { evaluate } from './evaluate.js'
import { register } from './register.js'
import { getWallet } from './services/wallets.js'
import { address } from './services/address.js'
import { spawnProcess } from './services/spawn-process.js'
import { gql } from './services/gql.js'
import { sendMessage } from './services/send-message.js'
import { readResult } from './services/read-result.js'
import ora from 'ora'
import chalk from 'chalk'
import { splash } from './services/splash.js'
import { version } from './services/version.js'
import { load } from './commands/load.js'

splash()

of()
  .chain(fromPromise(getWallet))
  .chain(jwk => register(jwk, { address, spawnProcess, gql })
    .map(id => ({ jwk, id }))
  )
  .toPromise()
  .then(async ({ jwk, id }) => {
    version(id)
    let prompt = await connect(jwk, id)

    let editorMode = false
    let editorData = ""

    async function repl() {

      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      });



      rl.question(editorMode ? "" : prompt, async function (line) {
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
  return promptResult.Output.data.prompt
}