const readline = require("readline");
const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const wasm = fs.readFileSync('./contract.wasm')
const handle = AoLoader(wasm)

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const AO = {
  process: {
    id: 'PROCESS_TEST',
    owner: 'TOM'
  }
}

function repl(state) {
  rl.question(state.prompt || "aos> ", async function (line) {
    // Exit the REPL if the user types "exit"
    if (line === "exit") {
      console.log("Exiting...");
      rl.close();
      return;
    }
    let response = {}
    // Evaluate the JavaScript code and print the result
    try {
      const message = createMessage(line)
      response = await handle(state, message, AO);
      console.log(JSON.stringify(response))
      console.log(response.result.output);
      // Continue the REPL
      repl(response.state);
    } catch (err) {
      console.log("Error:", err);
      process.exit(0)
    }


  });
}

repl({ inbox: [], owner: 'TOM', prompt: ":) ", _fns: {} });


function createMessage(expr) {
  return {
    owner: 'TOM',
    target: 'PROCESS',
    tags: {
      "Data-Protocol": "ao",
      "ao-type": "message",
      "function": "eval",
      "expression": expr
    }
  }
}