import fs from 'node:fs'
import path from 'node:path'
import { packageRoot } from '../package-root.js'

const pkg = JSON.parse(fs.readFileSync(path.join(packageRoot, 'package.json'), 'utf-8'))

export function getPkg() {
  return pkg
}
