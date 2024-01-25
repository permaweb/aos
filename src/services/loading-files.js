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
 * @param {Module[]} project 
 * @returns {string}
 */
export function createExecutableFromProject(project) {
  const moduleContents = project.map(
    (mod, i) => `function _loaded_mod_${i}()\n${mod.content}\nend`
  ).reduce((acc, con) => acc + '\n' + con, '')

  return moduleContents + '\n' + project.map(
    (mod, i) => `_G.package.loaded["${mod.name}"] = _loaded_mod_${i}()`
  ).reduce((acc, req) => acc + '\n' + req, '')
}

/**
 * Create the project structure from the main file's content
 * @param {string} mainFile
 * @return {Module[]}
 */
export function createProjectStructure(mainFile) {
  const modules = findRequires(mainFile)

  for (let i = 0; i < modules.length; i++) {
    if (modules[i].content || !fs.existsSync(modules[i].path)) continue

    modules[i].content = fs.readFileSync(modules[i].path, 'utf-8')

    const requiresInMod = findRequires(modules[i].content)
    requiresInMod.forEach((mod) => {
      const existingMod = modules.find((m) => m.name === mod.name)
      if (existingMod) {
        modules = modules.filter((m) => m.name !== existingMod.name)
      }
      modules.push(existingMod || mod)
    })
  }

  // only return modules that were found
  // if the module was not found, we assume it
  // is already loaded into aos
  // we also reverse the modules, because the
  // last modules are the first ones that need
  // to be imported
  return modules.filter((m) => !!m.content).reverse()
}

/**
 * @param {string} data
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
