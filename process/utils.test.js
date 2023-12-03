const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const wasm = fs.readFileSync('./process.wasm')
const assert = require('assert')

async function test() {
  const handle = await AoLoader(wasm)
  // find tags
  let response = await handle(null, {
    target: "PROCESS",
    tags: [
      { name: 'function', value: 'eval' },
      {
        name: 'expression', value: `
utils.find(
  utils.propEq("name")("expression")
)({{name="expression", value = "beep"}})
      `}
    ]
  }, { process: { id: 'FOO' } })
  //console.log(response.output)
  assert.equal(response.output.data.output.value, 'beep')

  let response2 = await handle(null, {
    target: "PROCESS",
    tags: [
      { name: 'function', value: 'eval' },
      {
        name: 'expression', value: `
utils.map(
  function (v)
    v.value = "boom"
    return v
  end)({
    {name="expression", value = "beep"}, 
    {name="what", value = "beep"}, 
    {name="right", value = "beep"}
  })
      `}
    ]
  }, { process: { id: 'FOO' } })
  console.log(response2.output.data.output)
  //assert.equal(response2.output.data.output.value, 'beep')
}

test()