import yargs from 'yargs/yargs'
import { hideBin } from 'yargs/helpers'
import readline from 'readline'
import path from 'path'
import fs from 'fs'
import { evaluate } from './evaluate.js'

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

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

let prompt = 'aos> '

async function repl() {
  rl.question(prompt, async function (line) {
    if (line === ".exit") {
      console.log("Exiting...");
      rl.close();
      return;
    }
    // check if process exists, if not register

    // create message and publish to ao
    const result = await evaluate(line)
    // capture output and prompt 
    // log output
    console.log(result.output)
    // set prompt
    prompt = result.prompt ? result.prompt : prompt
    repl()
  })
}

console.log('\nWelcome to AOS\nversion: v0.0.10\n')
repl()

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