import fs from 'fs'
import path from 'path'
import * as url from 'url';
import chalk from 'chalk'


const __dirname = url.fileURLToPath(new URL('.', import.meta.url));

export function loadBlueprint(line) {
  let name = line.split(' ')[1]
  const luaFile = __dirname + '../../blueprints/' + name + '.lua'
  if (fs.existsSync(path.resolve(luaFile))) {
    const code = fs.readFileSync(luaFile, 'utf-8')
    console.log(chalk.green('Loading... ', name));
    return code
  } else {
    throw Error(chalk.red('ERROR: .load-blueprint function requires a valid blueprint'))
  }
}