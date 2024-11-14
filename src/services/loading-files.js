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
 * @returns {[string, Module[]]}
 */
export function createExecutableFromProject(project) {
  const getModFnName = (name) => name.replace(/\./g, '_').replace(/^_/, '')
  /** @type {Module[]} */
  const contents = []

  // filter out repeated modules with different import names
  // and construct the executable Lua code
  // (the main file content is handled separately)
  for (let i = 0; i < project.length - 1; i++) {
    const mod = project[i]

    const existing = contents.find((m) => m.path === mod.path)
    const moduleContent = (!existing && `-- module: "${mod.name}"\nlocal function _loaded_mod_${getModFnName(mod.name)}()\n${mod.content}\nend\n`) || ''
    const requireMapper = `\n_G.package.loaded["${mod.name}"] = _loaded_mod_${getModFnName(existing?.name || mod.name)}()`

    contents.push({
      ...mod,
      content: moduleContent + requireMapper
    })
  }

  // finally, add the main file
  contents.push(project[project.length - 1])

  return [
    contents.reduce((acc, con) => acc + '\n\n' + con.content, ''),
    contents
  ]
}

/**
 * Create the project structure from the main file's content
 * @param {string} mainFile
 * @return {Module[]}
 */
export function createProjectStructure(mainFile) {
  const sorted = []
  const cwd = path.dirname(mainFile)

  // checks if the sorted module list already includes a node
  const isSorted = (node) => sorted.find(
    (sortedNode) => sortedNode.path === node.path
  )

  // recursive dfs algorithm
  function dfs(currentNode) {
    const unvisitedChildNodes = exploreNodes(currentNode, cwd).filter(
      (node) => !isSorted(node)
    )

    for (let i = 0; i < unvisitedChildNodes.length; i++) {
      dfs(unvisitedChildNodes[i])
    }

    if (!isSorted(currentNode))
      sorted.push(currentNode)
  }

  // run DFS from the main file
  dfs({ path: mainFile })

  return sorted.filter(
    // modules that were not read don't exist locally
    // aos assumes that these modules have already been
    // loaded into the process, or they're default modules
    (mod) => mod.content !== undefined
  )
}

/**
 * Find child nodes for a node (a module)
 * @param {Module} node Parent node
 * @param {string} cwd Project root dir
 * @return {Module[]}
 */
function exploreNodes(node, cwd) {
  if (!fs.existsSync(node.path)) return []

  // set content
  node.content = fs.readFileSync(node.path, 'utf-8')

  // Don't include requires that are commented (start with --)
  const requirePattern = /(?<!^.*--.*)(?<=(require( *)(\n*)(\()?( *)("|'))).*(?=("|'))/gm
  const requiredModules = node.content.match(requirePattern)?.map(
    (mod) => {
      return {
        name: mod,
        path: path.join(cwd, mod.replace(/\./g, '/') + '.lua'),
        content: undefined
      }
    }
  ) || []

  return requiredModules
}
