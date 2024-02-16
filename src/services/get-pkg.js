import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import * as url from 'url';

let __dirname = url.fileURLToPath(new URL('.', import.meta.url));

if (os.platform() === 'win32') {
  __dirname = __dirname.replace(/\\/g, "/").replace(/^[A-Za-z]:\//, "/")
}

const pkg = JSON.parse(fs.readFileSync(path.resolve(__dirname + '../../package.json')))

export function getPkg() {
  return pkg
}