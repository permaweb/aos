import minimist from 'minimist'
import path from 'path'
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
  const getModFnName = (name) => name.replace(/\./g, "_").replace(/^_/, "")
  const contents = []

  // filter out repeated modules with different import names
  // and construct the executable Lua code
  for (const mod of project) {
    const existing = contents.find((m) => m.path === mod.path);
    const moduleContent = (!existing && `-- module: "${mod.name}"\nfunction _loaded_mod_${getModFnName(mod.name)}()\n${mod.content}\nend\n`) || ''
    const requireMapper = `_G.package.loaded["${mod.name}"] = _loaded_mod_${getModFnName(existing?.name || mod.name)}()`

    contents.push({
      name: mod.name,
      path: mod.path,
      code: moduleContent + requireMapper
    })
  }

  return contents.reduce((acc, con) => acc + '\n\n' + con.code, '')
}

/**
 * Create the project structure from the main file's content
 * @param {string} mainFile
 * @param {string} cwd
 * @return {Module[]}
 */
export function createProjectStructure(mainFile, cwd) {
  const modules = findRequires(mainFile, cwd)
  let orderedModNames = modules.map((m) => m.name)

  for (let i = 0; i < modules.length; i++) {
    if (modules[i].content || !fs.existsSync(modules[i].path)) continue

    modules[i].content = fs.readFileSync(modules[i].path, 'utf-8')
      .split('\n')
      .map(v => '  ' + v)
      .join('\n')

    const requiresInMod = findRequires(modules[i].content, cwd)

    requiresInMod.forEach((mod) => {
      const existingMod = modules.find((m) => m.name === mod.name)
      if (!existingMod) {
        modules.push(mod)
      }

      const existingName = orderedModNames.find((name) => name === mod.name)
      if (existingName) {
        orderedModNames = orderedModNames.filter((name) => name !== existingName)
      }
      orderedModNames.push(existingName || mod.name)
    })
  }

  // Create an ordered array of modules,
  // we use this loop to reverse the order,
  // because the last modules are the first
  // ones that need to be imported
  // only add modules that were found
  // if the module was not found, we assume it
  // is already loaded into aos
  let orderedModules = []
  for (let i = orderedModNames.length; i > 0; i--) {
    const mod = modules.find((m) => m.name == orderedModNames[i - 1])
    if (mod && mod.content) {
      orderedModules.push(mod)
    }
  }

  return orderedModules
}

/**
 * @param {string} data
 * @param {string} cwd
 * @return {Module[]}
 */
function findRequires(data, cwd) {
  const requirePattern = /(?<=(require( *)(\n*)(\()?( *)("|'))).*(?=("|'))/g
  const requiredModules = data.match(requirePattern)?.map(
    (mod) => ({
      name: mod,
      path: path.join(cwd, mod.replace(/\./g, '/') + '.lua'),
      content: undefined
    })
  ) || []

  return requiredModules
}
