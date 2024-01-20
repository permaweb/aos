import fs from 'fs'
import path from 'path'
import * as url from 'url';
import chalk from 'chalk'


const __dirname = url.fileURLToPath(new URL('.', import.meta.url));


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