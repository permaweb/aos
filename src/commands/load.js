import createFileTree from 'pretty-file-tree'
import {
  createExecutableFromProject,
  createProjectStructure
} from '../services/loading-files.js'
import chalk from 'chalk'
import path from 'path'
import ora from 'ora'
import fs from 'fs'

export function load(line) {
  // get filename
  let fn = (line.split(' ')[1] || "").replace(/^("|')|("|')$/g, '')
  if (/\.lua$/.test(fn)) {
    let filePath = fn;
    if (!path.isAbsolute(filePath)) {
      filePath = path.resolve(path.join(process.cwd(), fn))
    }
    if (!fs.existsSync(filePath)) {
      throw Error(chalk.red('ERROR: file not found.'));
    }
    console.log(chalk.green('Loading... ', fn))

    const spinner = ora({
      spinner: 'dots',
      suffixText: ``,
      discardStdin: false
    })
    spinner.start()
    spinner.suffixText = chalk.gray('Parsing project structure...')
  
    const projectStructure = createProjectStructure(filePath)

    line = createExecutableFromProject(projectStructure)
    spinner.stop()

    if (projectStructure.length > 0) {
      console.log(chalk.yellow('\nThe following files will be deployed:'))
      console.log(chalk.dim(createFileTree(projectStructure.map((mod) => {
        if (mod.path === filePath) {
          mod.path += ' ' + chalk.reset(chalk.bgGreen(' MAIN '))
        }

        return mod.path
      }))))
    }

    return line
  } else {
    throw Error(chalk.red('ERROR: .load function requires a *.lua file'))
  }
}