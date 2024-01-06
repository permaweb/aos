import yargs from 'yargs/yargs'
import { hideBin } from 'yargs/helpers'
import readline from 'readline'
import path from 'path'
import fs from 'fs'
import os from 'os'
import { of, fromPromise, Resolved } from 'hyper-async'
import { evaluate } from './evaluate.js'
import { register } from './register.js'
import { createWallet } from './services/create-wallet.js'
import { address } from './services/address.js'
import { spawnProcess } from './services/spawn-process.js'
import { gql } from './services/gql.js'
import { sendMessage } from './services/send-message.js'
import { readResult } from './services/read-result.js'
import ora from 'ora'
import chalk from 'chalk'
import figlet from 'figlet'

figlet("aOS", {
  font: "Alpha",
  horizontalLayout: "full",
  verticalLayout: "full",
  width: 80,
  whitespaceBreak: true,
}, (e, d) => {
  console.log(chalk.gray(d))
  console.log(chalk.green('ao Operating System'))
})

let args = yargs(hideBin(process.argv)).argv

let jwk = null

if (args._[0]) {
  try {
    jwk = JSON.parse(fs.readFileSync(path.resolve(args._[0]), 'utf-8'))
  } catch (e) {
    console.log('aos ERROR: could not parse file!')
    process.exit(0)
  }
} else {
  if (fs.existsSync(path.resolve(os.homedir() + '/.aos.json'))) {
    jwk = JSON.parse(fs.readFileSync(path.resolve(os.homedir() + '/.aos.json'), 'utf-8'))
  }
}



let aosProcess = null
of(jwk)
  .chain(jwk => jwk ? Resolved(jwk) : fromPromise(createWallet)())
  .map(w => {
    jwk = w
    return w
  })
  .chain(jwk => register(jwk, { address, spawnProcess, gql }))
  .map(processId => {
    aosProcess = processId
    return `${chalk.gray("aos process: ")} ${chalk.green(processId)}`
  }).toPromise()
  .then(x => {

    console.log(chalk.gray(`
aos - 0.3.1 [alpha] 
2023 - Type ".exit" to exit`))
    console.log(x)
    console.log('')



    // need to check if a process is registered or create a process

    let prompt = 'aos> '


    let editorMode = false
    let editorData = ""

    async function repl() {

      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      });

      const spinner = ora({
        spinner: 'dots',
        suffixText: ``
      })

      rl.question(editorMode ? "" : prompt, async function (line) {
        if (/^\.load/.test(line)) {
          // get filename
          let fn = line.split(' ')[1]
          if (/\.lua$/.test(fn)) {
            console.log(chalk.green('Loading... ', fn));
            line = fs.readFileSync(path.resolve(process.cwd() + '/' + fn), 'utf-8');
          } else {
            console.log(chalk.red('ERROR: .load function requires a *.lua file'))
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
        spinner.start();
        spinner.suffixText = chalk.gray("[Signing message and sequencing...]")

        // create message and publish to ao
        const result = await evaluate(line, aosProcess, jwk, { sendMessage, readResult }, spinner)
          .catch(err => ({ Output: JSON.stringify({ data: { output: err.message } }) }))
        const output = result.Output //JSON.parse(result.Output ? result.Output : '{"data": { "output": "error: could not parse result."}}')

        // log output
        spinner.stop()
        if (result.Error) {
          console.log(result.Error)
        } else {
          console.log(output.data?.output)
        }

        // set prompt
        prompt = output.data.prompt ? output.data.prompt + '> ' : prompt
        rl.close()
        repl()
      })
    }

    repl()

  })