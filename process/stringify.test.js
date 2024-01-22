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
    Data: `
Handlers.add("foo", Handlers.utils.hasMatchingData("foo"), Handlers.utils.reply("bar"))
--return { a = "foo", b = "bar" }
return Handlers.list
    `
  }, { Process: { Id: 'FOO', Tags: [] } })
  console.log(response.Output)

  // let res2 = await handle(null, {
  //   Target: "PROCESS",
  //   Tags: [
  //     { name: 'Action', value: 'Eval' }
  //   ],
  //   Data: `{1,2,3}`
  // }, { Process: { Id: 'FOO', Tags: [] } })
  // console.log(res2.Output.data.output)
}

test()
