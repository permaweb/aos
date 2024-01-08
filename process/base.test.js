const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const wasm = fs.readFileSync('./process.wasm')


async function test() {
  const handle = await AoLoader(wasm)
  // add handler
  let response = await handle(null, {
    Target: "PROCESS",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: "1 + 1"
  }, { Process: { Id: 'FOO', Tags: [] } })
  console.log(response)
  //console.log(JSON.stringify(response.Output))
}

test()