import fs from 'fs'
import path from 'path'
import * as url from 'url';
import chalk from 'chalk'


const __dirname = url.fileURLToPath(new URL('.', import.meta.url));

const pkg = JSON.parse(fs.readFileSync(path.resolve(__dirname + '../../package.json')))

export function version(id) {
  console.log(chalk.gray(`
OS Version: ${pkg.version}. 2024
Type "Ctrl-C" to exit`))
  console.log(`${chalk.gray("aos process: ")} ${chalk.green(id)}`)
  console.log('')
}