import yargs from 'yargs/yargs'
import { hideBin } from 'yargs/helpers'
import readline from 'readline'
import path from 'path'
import fs from 'fs'
import { evaluate } from './evaluate.js'
import { register } from './register.js'
import { address } from './services/address.js'
import { spawnProcess } from './services/spawn-process.js'
import { gql } from './services/gql.js'
import { sendMessage } from './services/send-message.js'
import { readResult } from './services/read-result.js'


let args = yargs(hideBin(process.argv)).argv

if (!args._[0]) {
  console.log('AOS ERROR: arweave wallet file is required!')
  process.exit(0)
}
let jwk = null

try {
  jwk = JSON.parse(fs.readFileSync(path.resolve(args._[0]), 'utf-8'))
} catch (e) {
  console.log('AOS ERROR: could not parse file!')
  process.exit(0)
}

let aosProcess = null

register(jwk, { address, spawnProcess, gql })
  .map(processId => {
    aosProcess = processId
    return `Personal AOS Process: ${processId}`
  }).toPromise()
  .then(x => {
    console.log(x)

    console.log(`
AOS CLI - 0.1.0
2023 - Type ".exit" to exit

`)

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    // need to check if a process is registered or create a process

    let prompt = 'aos> '

    async function repl() {
      rl.question(prompt, async function (line) {
        if (line === ".exit") {
          console.log("Exiting...");
          rl.close();
          return;
        }

        // create message and publish to ao
        const result = await evaluate(line, aosProcess, jwk, { sendMessage, readResult })
        // capture output and prompt 
        console.log(JSON.stringify(result))
        // log output
        console.log(result.output)
        // set prompt
        prompt = result.prompt ? result.prompt : prompt
        repl()
      })
    }

    repl()

  })

/*





async function repl(state) {
  const handle = await AoLoader(wasm)

  rl.question(prompt + "> ", async function (line) {
    // Exit the REPL if the user types "exit"
    if (line === ".exit") {
      console.log("Exiting...");
      rl.close();
      return;
    }
    let response = {}
    // Evaluate the JavaScript code and print the result
    try {
      const message = createMessage(line)
      response = handle(state, message, env);
      console.log(response.output.data.output)
      if (response.output.data.prompt) {
        prompt = response.output.data.prompt
      }
      // Continue the REPL
      await repl(response.buffer);
    } catch (err) {
      console.log("Error:", err);
      process.exit(0)
    }


  });
}


repl(null);


function createMessage(expr) {
  return {
    owner: 'TOM',
    target: 'PROCESS',
    tags: [
      { name: "Data-Protocol", value: "ao" },
      { name: "ao-type", value: "message" },
      { name: "function", value: "eval" },
      { name: "expression", value: expr }
    ]
  }
}
*/