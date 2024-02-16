#!/usr/bin/env node
import url from 'url'
import path from 'node:path'
import os from 'node:os'

let __dirname = url.fileURLToPath(new URL('.', import.meta.url))

if (os.platform() === 'win32') {
  __dirname = __dirname.replace(/\\/g, "/").replace(/^[A-Za-z]:\//, "/")
  import(__dirname + '../src/index.js')
} else {
  import(path.resolve(__dirname + '../src/index.js'))
}