import semverCompare from 'semver/functions/compare.js'
import { createGunzip } from 'zlib'
import { Readable } from 'stream'
import tar from 'tar-stream'
import chalk from 'chalk'
import readline from 'readline/promises'
import { getPkg } from './get-pkg.js'
import path from 'path'
import fs from 'fs'

const UPDATE_URL = 'https://get_ao.g8way.io'
const pkg = getPkg()

export function version(id) {
  console.log(chalk.gray('Type ".load-blueprint chat" to join the community chat and ask questions!'))
  //console.log(chalk.gray('Type ".load-blueprint token" to create Social Token\n'))
  console.log(chalk.gray(`
OS Version: ${pkg.version}. 2024`))
  if (id) {
    console.log(chalk.gray('Type "Ctrl-C" twice to exit\n'))
    console.log(`${chalk.gray("aos process: ")} ${chalk.green(id)}`)
    console.log('')
  }
}

export const checkForUpdate = () => new Promise(async (resolve, reject) => {
  try {
    const res = await fetch(UPDATE_URL)
    const data = []
    const extract = tar.extract()
    if (res.status === 404) { return resolve({ available: false }) }
    Readable.fromWeb(res.body).pipe(createGunzip()).pipe(extract)

    extract.on('entry', (header, stream, next) => {
      const file = []

      stream.on('data', (chunk) => {
        file.push(chunk);
      })
      stream.on('end', () => {
        data.push({
          name: header.name,
          data: new TextDecoder().decode(
            Buffer.concat(file)
          )
        })
        next()
      })

      stream.resume()

    })
    extract.on('finish', () => {

      const packageJson = JSON.parse(
        data.find((f) => f.name === 'package/package.json')?.data || '{}'
      )

      if (!pkg.version) {
        console.log(chalk.red('ERROR: Could not check for update'))
        return resolve({ available: false })
      }

      resolve({
        available: semverCompare(pkg.version, packageJson.version) === -1,
        version: packageJson.version,
        data
      })
    })


  } catch {
    console.log(chalk.red('ERROR: Could not fetch update'))
    resolve({ available: false })
  }
})

export async function installUpdate(update, rootDir) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: true
  })
  const line = await rl.question(
    '✨ New version ' +
    chalk.green(update.version) +
    ' available. Would you like to update [Y/n]? '
  )

  if (!line.toLowerCase().startsWith('y')) {
    rl.close()
    return
  }

  try {
    for (const file of update.data) {
      const localPath = path.join(
        rootDir,
        file.name.replace(/^(\/)?package/, '')
      )

      // create path if it does not exist yet
      fs.mkdirSync(path.dirname(localPath), { recursive: true })
      fs.writeFileSync(
        localPath,
        new TextEncoder().encode(file.data)
      )
    }

    console.log(chalk.green(
      'Updated ' + pkg.version + ' → ' + update.version
    ))
    process.exit(0)
  } catch {
    console.log(chalk.red('ERROR: Failed to install update'))
  } finally {
    rl.close()
    process.exit(0)
  }
}
