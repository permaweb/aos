import fs from 'fs'
import path from 'path'
import * as url from 'url';

const __dirname = url.fileURLToPath(new URL('.', import.meta.url));

const pkg = JSON.parse(fs.readFileSync(path.resolve(__dirname + '../../package.json')))

export function getPkg() {
  return pkg
}