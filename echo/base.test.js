const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const wasm = fs.readFileSync('./process.wasm')


async function test() {
  const handle = await AoLoader(wasm)
  // add handler
  let response = await handle(null, {
    Target: "PROCESS",
    Tags: [
      { name: 'function', value: 'eval' },
      {
        name: 'expression', value: `1 + 1`
      }
    ]
  }, { Process: { Id: 'FOO', Tags: [] } })
  console.log(response.Output)
  //console.log(JSON.stringify(response.Output))
}

test()