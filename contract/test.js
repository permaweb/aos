const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')

async function main() {
  const wasm = fs.readFileSync('./contract.wasm')
  const handle = AoLoader(wasm)
  const result = await handle(
    {
      name: "AOS", owner: "tom", env: { logs: [] }
    },
    { caller: "tom", input: { function: "eval", data: "a = function(a,b) return a+b end" } },
    //{ caller: "tom", input: { function: "eval", data: "return foo" } },
    //{ caller: "tom", input: { function: "eval", data: "return 1 + 1" } },
    {}
  )
  console.log(JSON.stringify(result))

  console.log(await handle(
    result.state,
    //{ caller: "tom", input: { function: "eval", data: "foo = 'bar'" } },
    { caller: "tom", input: { function: "eval", data: "return a(40,2)" } },
    //{ caller: "tom", input: { function: "eval", data: "return 1 + 1" } },
    {}
  ))
}

main()