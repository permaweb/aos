/**
 * Process Registration Module
 *
 * Exports the `register` function to manage AO processes on Arweave's Permaweb:
 * - Finds existing processes/modules via GraphQL queries.
 * - Interactively prompts CLI users when multiple results are found.
 * - Creates AO processes with optional data payloads, cron schedules, and tags.
 */

import * as utils from './utils/hyper-utils.js'
import prompts from 'prompts'
import minimist from 'minimist'
import { getPkg } from './services/get-pkg.js'
import fs from 'fs'
import path from 'path'
import os from 'os'
import { resolveProcessTypeFromFlags } from './services/process-type.js'
import { config } from './config.js'
import ora from 'ora'
import { chalk } from './utils/colors.js'

// Local cache for process IDs and transaction data
const PROCESS_CACHE_FILE = path.join(os.homedir(), '.aos-process-cache.json')
const TX_CACHE_FILE = path.join(os.homedir(), '.aos-tx-cache.json')

function loadProcessCache() {
  try {
    if (fs.existsSync(PROCESS_CACHE_FILE)) {
      const data = fs.readFileSync(PROCESS_CACHE_FILE, 'utf-8')
      return JSON.parse(data)
    }
  } catch (e) {
    // Ignore cache errors
  }
  return {}
}

function saveProcessCache(cache) {
  try {
    fs.writeFileSync(PROCESS_CACHE_FILE, JSON.stringify(cache, null, 2))
  } catch (e) {
    // Ignore cache errors
  }
}

function getCachedProcess(address, name) {
  const cache = loadProcessCache()
  const key = `${address}:${name}`
  return cache[key]
}

function cacheProcess(address, name, processId, isMainnet = false) {
  const cache = loadProcessCache()
  const key = `${address}:${name}`
  cache[key] = {
    processId,
    isMainnet,
    timestamp: Date.now()
  }
  saveProcessCache(cache)
}

function loadTxCache() {
  try {
    if (fs.existsSync(TX_CACHE_FILE)) {
      const data = fs.readFileSync(TX_CACHE_FILE, 'utf-8')
      return JSON.parse(data)
    }
  } catch (e) {
    // Ignore cache errors
  }
  return {}
}

function saveTxCache(cache) {
  try {
    fs.writeFileSync(TX_CACHE_FILE, JSON.stringify(cache, null, 2))
  } catch (e) {
    // Ignore cache errors
  }
}

function getCachedTx(txId) {
  const cache = loadTxCache()
  return cache[txId]
}

function cacheTx(txId, tags) {
  const cache = loadTxCache()
  cache[txId] = {
    tags,
    timestamp: Date.now()
  }
  saveTxCache(cache)
}

const promptUser = results => {
  const choices = results.map((res, i) => {
    const format = res.node.tags.find(t => t.name === 'Module-Format')?.value ?? 'Unknown Format'
    const date = new Date(res.node.block.timestamp * 1000)
    const title = `${i + 1} - ${format} - ${res.node.id} - ${date.toLocaleString()}`

    return { title, value: res.node.id }
  })

  return prompts({
    type: 'select',
    name: 'module',
    message: 'Please select a module',
    choices,
    instructions: false
  })
    .then(r => r.module)
    .catch(() => Promise.reject({ ok: false, error: 'No module selected' }))
}

export async function register(jwk, services) {
  const argv = minimist(process.argv.slice(2))
  const name = argv._[0] || 'default'

  let spawnTags = Array.isArray(argv['tag-name'])
    ? argv['tag-name'].map((name, i) => ({
      name: String(name || ''),
      value: String(argv['tag-value'][i] || '')
    }))
    : []
  if (spawnTags.length === 0 && typeof argv['tag-name'] === 'string') {
    spawnTags = [
      {
        name: String(argv['tag-name'] || ''),
        value: String(argv['tag-value'] || '')
      }
    ]
  }

  // Handle direct address lookup
  if (services.isAddress(name)) {
    try {
      // Check cache first
      const cachedTx = getCachedTx(name)
      let tags
      let variant

      if (cachedTx) {
        tags = cachedTx.tags
        const variantTag = tags.find(tag => tag.name.toLowerCase() === 'variant')
        variant = variantTag?.value
      } else {
        // Fetch from gateway if not cached
        const gqlUrl = config.urls.GATEWAY
        const res = await fetch(`${gqlUrl}/graphql`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            query: `query ($id: ID!) { transaction(id: $id) { tags { name value } } }`,
            variables: { id: name }
          })
        })

        if (res.ok) {
          const data = await res.json()
          tags = data.data.transaction.tags
          const variantTag = tags.find(tag => tag.name.toLowerCase() === 'variant')
          variant = variantTag?.value

          // Cache the transaction data
          cacheTx(name, tags)
        } else {
          return { id: name, variant: null }
        }
      }

      if (variant === 'ao.N.1' && (!process.env.AO_URL || process.env.AO_URL === 'undefined')) {
        process.env.AO_URL = config.urls.DEFAULT_HB_NODE
      }

      return { id: name, variant }
    } catch (error) {
      // If lookup fails, just return the name
      return { id: name, variant: null }
    }
  }

  // Main registration flow
  try {
    // Get wallet address
    const address = await services.address(jwk)

    // Find existing process
    let processId
    try {
      // No process found - create new one
      const spinner = ora({
        spinner: 'dots',
        suffixText: ''
      })

      spinner.start()
      spinner.suffixText = chalk.gray('[Searching For Process...]')

      const gqlResult = await services.gql(queryForAOS(name), {
        owners: [address, argv.address || '']
      })
      const edges = utils.path(['data', 'transactions', 'edges'])(gqlResult)

      spinner.stop()

      if (edges && edges.length > 0) {
        // Process found - handle selection
        const result = await handleExistingProcess(edges.reverse())
        return result
      }
    } catch (gqlError) {
      // GQL error or no process found - proceed to create new process
    }

    // No process found - create new one
    const spinner = ora({
      spinner: 'dots',
      suffixText: ''
    })

    spinner.start()
    spinner.suffixText = chalk.gray('[Spawning New Process...]')

    const module = await findModule(services, argv.module)
    processId = await createProcess(jwk, name, spawnTags, module, services)

    spinner.stop()

    return { id: processId, variant: null }
  } catch (error) {
    throw error
  }
}

async function handleExistingProcess(results) {
  if (results.length === 1) {
    // Single process found
    const variant = results[0].node.tags.find(t => t.name.toLowerCase() === 'variant')?.value
    return { id: results[0].node.id, variant }
  }

  // Multiple processes found - prompt user
  const processes = results.map((r, i) => {
    const version = r.node.tags.find(t => t.name.toLowerCase() === 'aos-version')?.value
    const variant = r.node.tags.find(t => t.name.toLowerCase() === 'variant')?.value

    return {
      title: `${i + 1} - ${r.node.id} - ${variant} - v${version}`,
      value: r.node.id,
      variant
    }
  })

  const response = await prompts({
    type: 'select',
    name: 'process',
    message: 'Select A Process',
    choices: processes,
    instructions: false
  })

  if (!response.process) {
    throw new Error('No process selected')
  }

  const selectedProcess = processes.find(p => p.value === response.process)
  return { id: response.process, variant: selectedProcess?.variant }
}

async function findModule(services, moduleArg) {
  const AOS_MODULE = process.env.AOS_MODULE
  const AOS_MODULE_NAME = process.env.AOS_MODULE_NAME

  // Use default module
  if (!AOS_MODULE && !AOS_MODULE_NAME) {
    return getPkg().aos.module
  }

  // Use specified module ID
  if (AOS_MODULE) {
    return AOS_MODULE
  }

  // Look up module by name
  try {
    const gqlResult = await services.gql(findAoModuleByName(), { name: moduleArg })
    const edges = utils.path(['data', 'transactions', 'edges'], gqlResult)

    if (!edges || edges.length === 0) {
      throw new Error('No module found with provided name.')
    }

    // Single module found
    if (edges.length === 1) {
      return edges[0].node.id
    }

    // Multiple modules - prompt user
    const moduleId = await promptUser(edges)
    return moduleId
  } catch (error) {
    throw new Error(error.message || 'Error finding module')
  }
}

async function createProcess(jwk, name, spawnTags, module, services) {
  let appName = 'aos'

  let data = ''
  let tags = [
    { name: 'App-Name', value: appName },
    { name: 'Name', value: name },
    ...(spawnTags || [])
  ]

  const argv = minimist(process.argv.slice(2))
  const cronExp =
    /^\d+\-(second|seconds|minute|minutes|hour|hours|day|days|month|months|year|years|block|blocks|Second|Seconds|Minute|Minutes|Hour|Hours|Day|Days|Month|Months|Year|Years|Block|Blocks)$/

  if (argv.cron) {
    if (cronExp.test(argv.cron)) {
      tags = [
        ...tags,
        { name: 'Cron-Interval', value: argv.cron },
        { name: 'Cron-Tag-Action', value: 'Cron' }
      ]
    } else {
      throw Error('Invalid cron flag!')
    }
  }

  if (argv.data) {
    if (fs.existsSync(path.resolve(argv.data))) {
      data = fs.readFileSync(path.resolve(argv.data), 'utf-8')
    }
  }

  // Use appropriate spawn service
  const processType = resolveProcessTypeFromFlags(argv)

  if (processType === 'mainnet' || process.env.AO_URL !== 'undefined') {
    if (process.env.AO_URL === 'undefined') {
      process.env.AO_URL = config.urls.DEFAULT_HB_NODE
      process.env.SCHEDULER = config.addresses.SCHEDULER_MAINNET
      process.env.AUTHORITY = 'undefined'
    }

    return await services.spawnProcessMainnet({
      wallet: jwk,
      src: module,
      tags,
      data,
      isHyper: true
    })
  }

  else {
    tags.push({ name: 'Authority', value: 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY' });

    return await services.spawnProcess({
      wallet: jwk,
      src: module,
      tags,
      data
    })
  }
}

function queryForAOS(name) {
  return `query ($owners: [String!]!) {
    transactions(
      first: 10,
      owners: $owners,
      tags: [
        { name: "Data-Protocol", values: ["ao"] },
        { name: "Type", values: ["Process"]},
        { name: "Name", values: ["${name}"]}
      ]
    ) {
      edges {
        node {
          id
          tags {
            name
            value
          }
        }
      }
    }
  }`
}

function findAoModuleByName() {
  return `query FindAoModuleByName($name: String!) {
    transactions(
      tags: [
        { name: "Type", values: ["Module"] },
        { name: "Data-Protocol", values: ["ao"] },
        { name: "Name", values: [$name] }
      ],
      sort: HEIGHT_DESC,
      first: 100
    ) {
      edges {
        node {
          id
          tags {
            name
            value
          }
          block {
            timestamp
          }
        }
      }
    }
  }`
}
