import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import * as url from 'url'
import chalk from 'chalk'


let __dirname = url.fileURLToPath(new URL('.', import.meta.url));
if (os.platform() === 'win32') {
  __dirname = __dirname.replace(/\\/g, "/").replace(/^[A-Za-z]:\//, "/")
}

export function blueprints(dir) {
  try {
    if (dir === true) {
      dir = __dirname + "../../blueprints"
    }
    let prints = fs.readdirSync(path.resolve(dir))

    prints.map(n => {
      return [n, fs.readFileSync(path.resolve(dir + '/' + n), 'utf-8')]
    }).map(([n, lua]) => {
      fs.writeFileSync(path.resolve(process.cwd() + '/' + n), lua)
    })
  } catch (e) {
    console.error(chalk.red('BLUEPRINT ERROR: Having trouble finding directory or reading files!'))
  }

}