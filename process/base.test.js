const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const wasm = fs.readFileSync('./process.wasm')


async function test() {
  const handle = await AoLoader(wasm)
  // add handler
  let response = await handle(null, {
    Target: "PROCESS",
    From: "MTTgc7nUwSfRpUH4p4F0q43n_-igr5Ki8OCPtjNGfhM",
    Tags: [
      { name: 'Action', value: 'Cron' }
    ],
    Data: "Foo Bar Baz Beep Boop FoobarBeepBoop simple string over 20 characters"
    // Data: `
    // local json = require('json')
    // ao.send({Target = "foo", Action = "bar" })
    // print("Sent a Message")
    // return json.encode(ao.outbox.Output)
    //`
  }, { Process: { Id: 'FOO', Tags: [] } })
  console.log(JSON.stringify(response.Output))
  //console.log(JSON.stringify(response.Output))
}

test()