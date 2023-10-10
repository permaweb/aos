const test = require("node:test")
const assert = require('assert/strict')

const AoLoader = require('@permaweb/ao-loader')
const fs = require('fs')
const wasm = fs.readFileSync('./contract.wasm')
const handle = AoLoader(wasm)

const state = {
  name: "Personal AOS",
  owner: "tom",
  inbox: [],
  env: { logs: [] }
}

test("eval basic", async () => {
  const action = {
    caller: "tom",
    input: {
      function: "eval",
      data: "return \"Hello World\""
    }
  }
  const result = await handle(state, action, {})
  //console.log(result)
  assert.equal(result.result.output, 'Hello World')
})

test("eval checkMsgs", async () => {
  const s = { ...state, inbox: [{ from: 'bob', body: 'Hi' }] }
  const action = {
    caller: "tom",
    input: {
      function: "eval",
      data: "return checkMsgs()"
    }
  }
  const res = await handle(s, action, {})
  //console.log(res)
  assert.deepEqual(JSON.parse(res.result.output), [{ "body": "Hi", "from": "bob" }])
})

test("eval sendMsg", async () => {
  const action = {
    caller: "tom",
    input: {
      function: "eval",
      data: "return sendMsg(\"tom\", \"hi\")"
    }
  }
  const res = await handle(state, action, { contract: { id: "foo" } })
  assert.equal(res.result.output, "message queued to send")
  assert.deepEqual(res.result.messages[0], { message: { function: 'receiveMsg', from: 'foo', body: 'hi' }, target: 'tom' })
})

test("eval inbox", async () => {
  const s = { ...state, inbox: [{ from: 'bob', body: 'Hi' }] }
  const action = {
    caller: "tom",
    input: {
      function: "eval",
      data: "a = function() local o = \"\"; for i,v in _global.ipairs(inbox) do o = o .. v.body .. \", \" end; return o; end; return a();"
    }
  }
  const res = await handle(s, action, {})
  assert.equal(res.result.output, 'Hi, ')
})

test("eval set receiveFn", async () => {
  const s = { ...state, inbox: [{ from: 'bob', body: 'Hi' }] }
  const action = {
    caller: "tom",
    input: {
      function: "eval",
      data: "return setReceiveFn(\"return { target = state.inbox[#state.inbox].from, message = { ['function'] = 'receiveMsg', body = 'Thank you for sending message', from = SmartWeave.contract.id }} \");"
    }
  }
  const res = await handle(s, action, {})
  assert.equal(res.result.output, 'set receive function')

  const message = {
    caller: 'MU',
    input: {
      function: 'handleMessage',
      message: {
        function: 'receiveMsg',
        from: 'tom',
        body: 'Hello World'
      }
    }
  }
  const res2 = await handle(res.state, message, { contract: { id: "PROCESS" } })
  //console.log(res2.result)
  assert.equal(res2.result.output, 'processed message')
})