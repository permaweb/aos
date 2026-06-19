import fs from 'node:fs'
import path from 'node:path'
import { packageRoot } from '../package-root.js'
import { chalk } from '../utils/colors.js'

export function blueprints(dir) {
  try {
    const blueprintsDir = path.join(packageRoot, 'blueprints')
    const outputDir = process.cwd() + '/' + (dir === true ? '' : dir)

    let prints = fs.readdirSync(blueprintsDir)
    prints
      .map(n => {
        return [n, fs.readFileSync(path.join(blueprintsDir, n), 'utf-8')]
      })
      .map(([n, lua]) => {
        fs.writeFileSync(path.resolve(outputDir + '/' + n), lua)
      })
  } catch (e) {
    console.error(chalk.red('BLUEPRINT ERROR: Having trouble finding directory or reading files!'))
  }
}
