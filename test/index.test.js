import { test } from 'node:test'
import * as assert from 'node:assert'
import { spawn } from 'node:child_process'

test('aos', async (done) => {
  let repl;
  let output = '';

  repl = spawn('node', ['src/index.js', 'club-random'])

  repl.stdout.on('data', (data => {
    output += data.toString();
  }))

  repl.stdin.write('1 + 1\n')

  const res = await new Promise(r => setTimeout(() => {
    const lines = output.split('\n')
    output = ""
    r(lines[lines.length - 2])
  }, 10000))

  assert.equal(res.trim(), '\x1B[33m2\x1B[39m')

  repl.stdin.write('print("Hello World")\n')

  const res2 = await new Promise(r => setTimeout(() => {
    const lines = output.split('\n')
    r(lines[lines.length - 2])
  }, 2000))

  assert.equal(res2.trim(), 'Hello World')

  repl.stdin.end()

  repl.kill('SIGINT')
  repl.kill('SIGINT')

})