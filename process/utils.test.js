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
return Utils.find(
  Utils.propEq("name")("expression"))
  ({{name = "expression", value = "beep" }}
)
    `
  }, { Process: { Id: 'FOO', Tags: [] } })
  //console.log(response.Output)
  assert.equal(response.Output.data.output.value, 'beep')

  let response2 = await handle(null, {
    Target: "PROCESS",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: `
    Utils.map(
      function (v)
        v.value = "boom"
        return v
      end)({
        {name="expression", value = "beep"}, 
        {name="what", value = "beep"}, 
        {name="right", value = "beep"}
      })
          `
  }, { Process: { Id: 'FOO', Tags: [] } })

  assert.deepStrictEqual(response2.Output.data.output, [
    { name: 'expression', value: 'boom' },
    { name: 'what', value: 'boom' },
    { name: 'right', value: 'boom' }
  ])

  let response3 = await handle(null, {
    Target: "PROCESS",
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: `
     Utils.filter(
      function (v)
        return v.value == 'beep'
      end)({
        {name="expression", value = "beep"}, 
        {name="what", value = "boop"}, 
        {name="right", value = "beep"}
      })
          `
  }, { Process: { Id: 'FOO', Tags: [] } })
  assert.deepStrictEqual(response3.Output.data.output, [
    { name: 'expression', value: 'beep' },
    { name: 'right', value: 'beep' }
  ])

}

test()