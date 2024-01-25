import minimist from 'minimist'
import fs from 'fs'

export function checkLoadArgs() {
  const argv = minimist(process.argv.slice(2))
  if (argv.load) {
    if (typeof argv.load === 'string') {
      return [argv.load]
    }
    return argv.load
  }
  return []
}

/**
 * @typedef Module
 * @property {string} name
 * @property {string} path
 * @property {string|undefined} content
 */

/**
 * Create the project structure from the main file's content
 * @return {Module[]}
 */
export function createProjectStructure(mainFile) {
  const modules = findRequires(mainFile)

  for (let i = 0; i < modules.length; i++) {
    if (modules[i].content || !fs.existsSync(modules[i].path)) continue

    modules[i].content = fs.readFileSync(modules[i].path, 'utf-8')

    const requiresInMod = findRequires(modules[i].content)
    requiresInMod.forEach((mod) => {
      if (modules.find((m) => m.name === mod.name)) return
      modules.push(mod)
    })
  }

  return modules
}

/**
 * @return {Module[]}
 */
function findRequires(data) {
  const requirePattern = /(?<=(require( *)(\n*)(\()?( *)("|'))).*(?=("|'))/g
  const requiredModules = data.match(requirePattern)?.map(
    (mod) => ({
      name: mod,
      path: path.join(
        process.cwd(),
        mod.replace(/\./g, '/') + '.lua'
      ),
      content: undefined
    })
  ) || []

  return requiredModules
}
