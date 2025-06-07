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
    const blueprintsDir = __dirname + "../../blueprints" 
    const outputDir = process.cwd() + '/' + (dir === true ? '' : dir)

    let prints = fs.readdirSync(path.resolve(blueprintsDir))
    prints.map(n => {
      return [n, fs.readFileSync(path.resolve(blueprintsDir + '/' + n), 'utf-8')]
    }).map(([n, lua]) => {
      fs.writeFileSync(path.resolve(outputDir + '/' + n), lua)
    })
  } catch (e) {
    console.error(chalk.red('BLUEPRINT ERROR: Having trouble finding directory or reading files!'))
  }

}