import minimist from 'minimist'
import path from 'path'
import fs from 'fs'

export function checkLoadArgs() {
  const argv = minimist(process.argv.slice(2))
  if (argv.load) {
    if (typeof argv.load === 'string') {
      return [argv.load]
    }
    if (typeof argv.load === 'boolean') {
      return []
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
    const moduleContent = (!existing && `-- module: "${mod.name}"\nlocal function _loaded_mod_${getModFnName(mod.name)}()\n${mod.content}\nend\n`) || ''
    const requireMapper = `\n_G.package.loaded["${mod.name}"] = _loaded_mod_${getModFnName(existing?.name || mod.name)}()`

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
 * @return {Module[]}
 */
export function createProjectStructure(mainFile) {
  const sorted = []
  const cwd = path.dirname(mainFile)

  /**
   * Recursive dfs algorithm
   */
  function dfs(currentNode) {
    const unvisitedChildNodes = exploreNodes(currentNode.path, cwd).filter(
      (node) => !sorted.find((sortedNode) => sortedNode.path === node.path)
    )

    for (let i = 0; i < unvisitedChildNodes.length; i++) {
      dfs(unvisitedChildNodes[i])
    }

    sorted.push(currentNode)
  }

  // run DFS from the main file
  dfs({ path: mainFile })

  return sorted
}

/**
 * Find child nodes for a node (a module)
 * @param {string} node Parent node
 * @param {string} cwd Project root dir
 * @return {Module[]}
 */
function exploreNodes(node, cwd) {
  if (!fs.existsSync(node)) return []

  const content = fs.readFileSync(node, 'utf-8')
  const requirePattern = /(?<=(require( *)(\n*)(\()?( *)("|'))).*(?=("|'))/g
  const requiredModules = content.match(requirePattern)?.map(
    (mod) => ({
      name: mod,
      path: path.join(cwd, mod.replace(/\./g, '/') + '.lua'),
      content: undefined
    })
  ) || []

  return requiredModules
}
