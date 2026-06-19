import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

export const packageRoot = findPackageRoot(path.dirname(fileURLToPath(import.meta.url)))

function findPackageRoot(startDirectory) {
  let directory = startDirectory

  while (true) {
    if (fs.existsSync(path.join(directory, 'package.json'))) {
      return directory
    }

    const parent = path.dirname(directory)

    if (parent === directory) {
      throw new Error(`Unable to find the AOS package root from ${startDirectory}`)
    }

    directory = parent
  }
}
