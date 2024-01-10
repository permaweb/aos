import fs from 'fs'
import chalk from 'chalk'
import path from 'path'

export function load(line) {
  // get filename
  let fn = line.split(' ')[1]
  if (/\.lua$/.test(fn)) {
    if (!fs.existsSync(path.resolve(process.cwd() + '/' + fn))) {
      throw Error(chalk.red('ERROR: file not found.'));
    }
    console.log(chalk.green('Loading... ', fn));
    line = fs.readFileSync(path.resolve(process.cwd() + '/' + fn), 'utf-8');
    return line
  } else {
    throw Error(chalk.red('ERROR: .load function requires a *.lua file'))
  }
}