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
  let fn = line.split(' ')[1].replace(/^("|')|("|')$/g, '')
  if (/\.lua$/.test(fn)) {
    let filePath = fn;
    if (!path.isAbsolute(filePath)) {
      filePath = path.resolve(path.join(process.cwd(), fn))
    }
    if (!fs.existsSync(filePath)) {
      throw Error(chalk.red('ERROR: file not found.'));
    }
    console.log(chalk.green('Loading... ', fn))
    line = fs.readFileSync(filePath, 'utf-8')

    const spinner = ora({
      spinner: 'dots',
      suffixText: ``
    })
    spinner.start()
    spinner.suffixText = chalk.gray('Parsing project structure...')
    const projectStructure = createProjectStructure(
      line,
      path.dirname(filePath)
    )
    if (projectStructure.length > 0) {
      line = createExecutableFromProject(projectStructure) + '\n\n' + line
      console.log(line)
    }
    spinner.stop()

    if (projectStructure.length > 0) {
      console.log(chalk.yellow('\nThe following files will be deployed:'))
      console.log(chalk.dim(createFileTree([
        ...projectStructure.map(m => m.path),
        filePath + ' ' + chalk.reset(chalk.bgGreen(' MAIN '))
      ])))
    }

    return line
  } else {
    throw Error(chalk.red('ERROR: .load function requires a *.lua file'))
  }
}