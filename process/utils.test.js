const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const wasm = fs.readFileSync('./process.wasm')
const assert = require('assert')

async function test() {
  const handle = await AoLoader(wasm)
  // find tags
  let response = await handle(null, {
    Target: "PROCESS",
    Tags: [
      { name: 'Action', value: 'Eval' },
    ],
    Data: `
return Utils.prop("value", 
  Utils.find(
    Utils.propEq("name")("expression"))
    ({{name = "expression", value = "beep" }}
  )
)
    `
  }, { Process: { Id: 'FOO', Tags: [] } })

  assert.equal(response.Output.data.output, 'beep')

}

test()
