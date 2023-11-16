const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')

const wasm = fs.readFileSync('./process.wasm')

async function main() {
  const handle = await AoLoader(wasm)
  try {
    const result = await handle(null, {
      owner: "TOM",
      tags: [
        { name: "Forwarded-For", value: "POTATO" },
        { name: "msg", value: "hello" }
      ]
    }, { process: { id: "BOT" } })
    console.log(result.output)
    console.log(result.messages)
  } catch (err) {
    console.log(err)
  }
}

main()