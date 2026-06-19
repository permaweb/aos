import fs from 'fs'
import path from 'path'
import { packageRoot } from '../package-root.js'
import { chalk } from '../utils/colors.js'

export function loadBlueprint(line) {
  let name = line.split(' ')[1]
  const luaFile = path.join(packageRoot, 'blueprints', `${name}.lua`)
  if (fs.existsSync(luaFile)) {
    const code = fs.readFileSync(luaFile, 'utf-8')
    console.log(chalk.green('Loading... ', name))
    return code
  } else {
    throw Error(chalk.red('ERROR: .load-blueprint function requires a valid blueprint'))
  }
}
