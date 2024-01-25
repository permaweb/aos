import { createProjectStructure } from '../services/loading-files.js'
import fs from 'fs'
import chalk from 'chalk'
import path from 'path'

export function load(line) {
  // get filename
  let fn = line.split(' ')[1]
  if (/\.lua$/.test(fn)) {
    let filePath = fn;
    if (!path.isAbsolute(filePath)) {
      filePath = path.resolve(path.join(process.cwd(), fn))
    }
    if (!fs.existsSync(filePath)) {
      throw Error(chalk.red('ERROR: file not found.'));
    }
    console.log(chalk.green('Loading... ', fn));
    line = fs.readFileSync(filePath, 'utf-8');
    //console.log(createProjectStructure(line).map((m) => ({ name: m.name, path: m.path })))
    return line
  } else {
    throw Error(chalk.red('ERROR: .load function requires a *.lua file'))
  }
}