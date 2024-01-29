import semverCompare from 'semver/functions/compare.js'
import { createGunzip } from 'zlib'
import { Readable } from 'stream'
import tar from 'tar-stream'
import fs from 'fs'
import path from 'path'
import * as url from 'url';
import chalk from 'chalk'


const __dirname = url.fileURLToPath(new URL('.', import.meta.url));

const pkg = JSON.parse(fs.readFileSync(path.resolve(__dirname + '../../package.json')))

export function version(id) {
  console.log(chalk.gray(`
OS Version: ${pkg.version}. 2024`))
  if (id) {
    console.log(chalk.gray('Type "Ctrl-C" to exit\n'))
    console.log(`${chalk.gray("aos process: ")} ${chalk.green(id)}`)
    console.log('')
  }
}

export const checkForUpdate = () => new Promise(async (resolve, reject) => {
  try {
    const res = await fetch('https://get_ao.g8way.io')
    const data = []
    const extract = tar.extract()

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
      
      resolve({
        available: semverCompare(pkg.version, packageJson.version),
        data
      })
    })
  } catch (e) {
    reject(e)
  }
})
