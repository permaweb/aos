const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const wasm = fs.readFileSync('./process.wasm')


async function test() {
  const handle = await AoLoader(wasm)
  // add handler
  let response = await handle(null, {
    target: "PROCESS",
    tags: [
      { name: 'function', value: 'eval' },
      {
        name: 'expression', value: `
  handlers.append(
    function (msg)
      for i, o in ipairs(msg.tags) do
        if o.name == "body" and o.value == "ping" then
          return -1
        end
      end
      return 0
    end,
    function (msg)
      table.insert(inbox, msg)
      ao.send({body = "pong"}, msg.from)
    end,
    "pingpong"
  )
        `}
    ]
  }, { process: { id: 'FOO' } })
  //   // send message
  let response2 = await handle(response.buffer, {
    target: 'PROCESS',
    from: 'FOO',
    tags: [
      { name: 'body', value: 'ping' }
    ]
  }, { process: { id: 'FOO' } })
  // confirm response
  console.log(response2.output)
  console.log(response2.messages)
  let response3 = await handle(response2.buffer, {
    target: 'PROCESS',
    from: 'FOO',
    tags: [
      { name: 'body', value: 'ping' }
    ]
  }, { process: { id: 'FOO' } })
  // confirm response
  console.log(response3.output)
  console.log(response3.messages)

}

test()