const readline = require("readline");
const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const wasm = fs.readFileSync('./process.wasm')

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const env = {
  Process: {
    Id: 'PROCESS_TEST',
    Owner: 'TOM'
  }
}
let prompt = 'aos'

async function repl(state) {
  const handle = await AoLoader(wasm)

  rl.question(prompt + "> ", async function (line) {
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
      response = handle(state, message, env);
      console.log(response.Output)
      if (response.Output.data.output) {
        console.log(response.Output.data.output)
      }
      //console.log(response.messages)
      if (response.Output.data.prompt) {
        prompt = response.Output.data.prompt
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
    Owner: 'TOM',
    Target: 'PROCESS',
    Tags: [
      { name: "Data-Protocol", value: "ao" },
      { name: "Variant", value: 'ao.TN.1' },
      { name: "Type", value: "message" },
      { name: "function", value: "eval" },
      { name: "expression", value: expr }
    ]
  }
}

/**
 * const spawn = {
  owner: "TOM",
  tags: [

    { name: "Data-Protocol", value: "ao" },
    { name: "ao-type", value: "spawn" },
    { name: "function", value: "eval" },
    { name: "expression", value: expr }

  ]
}

 */