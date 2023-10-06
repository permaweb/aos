const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')

async function main() {
  const wasm = fs.readFileSync('./contract.wasm')
  console.time('aos')
  const handle = AoLoader(wasm)
  console.timeEnd('aos')
  console.time('aos2')
  const result = await handle(
    {
      name: "AOS", owner: "tom", env: { logs: [] }, inbox: ["This is msg1", "this is msg2"]
    },
    {
      caller: "tom", input: {
        function: "eval",
        data: "return \"messages: \" .. checkMsgs()"
      }
    },
    {
      transaction: {
        tags: {
          Caller: "tom"
        }
      }
    }
  )
  console.timeEnd('aos2')
  console.log(JSON.stringify(result))

}

main()