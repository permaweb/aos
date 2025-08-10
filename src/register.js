/**
 * Process Registration Module
 *
 * Exports the `register` function to manage AO processes on Arweave's Permaweb:
 * - Finds existing processes/modules via GraphQL queries.
 * - Interactively prompts CLI users when multiple results are found.
 * - Creates AO processes with optional data payloads, cron schedules, and tags.
 *
 * Built with functional async (`hyper-async`), minimist (CLI args), prompts
 * (interactive selection), and file-system utilities for enhanced flexibility.
 */

import { of, Resolved, Rejected, fromPromise } from 'hyper-async'
import * as utils from './hyper-utils.js'
import prompts from 'prompts'
import minimist from 'minimist'
import { getPkg } from './services/get-pkg.js'
import fs from 'fs'
import path from 'path'

const promptUser = (results) => {
  const choices = results.map((res, i) => {
    const format = res.node.tags.find((t) => t.name === 'Module-Format')?.value ?? 'Unknown Format'
    const date = new Date(res.node.block.timestamp * 1000)
    const title = `${i + 1} - ${format} - ${res.node.id} - ${date.toLocaleString()}`

    return {title, value: res.node.id}
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

export function register(jwk, services) {
  const getAddress = ctx => services.address(ctx.jwk).map(address => ({ address, ...ctx }))
  const findProcess = (ctx) => {
    const { address, name } = ctx
    const argv = minimist(process.argv.slice(2))
    const gqlQueryError = _ => Rejected({ ok: false, error: 'GRAPHQL Error trying to locate process.' }) 
    const handleQueryResults = results => results?.length > 0
      ? Resolved(results.reverse())
      : Rejected({ ...ctx, ok: true })

    return services
      .gql(queryForAOS(name), { owners: [address, argv.address || ""] })
      .map(utils.path(['data', 'transactions', 'edges']))
      .bichain(gqlQueryError, handleQueryResults)
  }
  
  const getResultId = results => results.length === 1
    ? Resolved(results[0].node.id)
    : Rejected(results)

  const selectModule = (results) =>
    of(results).chain((results) => !results?.length
      ? Rejected({ ok: false, error: 'No module found with provided name.' })
      : of(results)
        .chain(getResultId)
        .bichain(fromPromise(promptUser), Resolved)
    )

  const findModule = ctx => {
    const AOS_MODULE = process.env.AOS_MODULE;
    const AOS_MODULE_NAME = process.env.AOS_MODULE_NAME;

    if (!AOS_MODULE && !AOS_MODULE_NAME) return Resolved({ ...ctx, module: getPkg().aos.module });
    if (AOS_MODULE) return Resolved({ ...ctx, module: AOS_MODULE });
    
    return services
      .gql(findAoModuleByName(), { name: ctx.module })
      .map(utils.path(['data', 'transactions', 'edges']))
      .chain(selectModule)
      .map((moduleId) => ({ ...ctx, ok: true, module: moduleId }))
  }
 
  // pick the process type for new process, it can be either aos or hyper-aos
  const pickProcessType = fromPromise(async function (ctx) {
    const processOS = await prompts({
      type: 'select',
      name: 'device',
      message: 'Please select',
      choices: [{ title: 'aos (stable-production-ready)', value: 'aos' }, { title: 'hyper-aos (experimental - DO NOT USE FOR PRODUCTION)', value: 'hyper' }],
      instructions: false
    }).then(res => res.device).catch(e => "aos")
    ctx.processType = processOS
    return ctx
  })

  const createProcess = (ctx) => {
    const { ok, name, spawnTags, module, error } = ctx
    if (!ok) {
      return Rejected({ error: error || 'Unknown error occured' })
    }
    let appName = "aos"
    if (process.env.AO_URL !== "undefined") {
      appName = "hyper-aos"
    }
    let data = "1984"
    let tags = [
      { name: 'App-Name', value: appName },
      { name: 'Name', value: name },
      { name: 'Authority', value: 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY' },
      ...(spawnTags || [])
    ]
    const argv = minimist(process.argv.slice(2))
    const cronExp = /^\d+\-(second|seconds|minute|minutes|hour|hours|day|days|month|months|year|years|block|blocks|Second|Seconds|Minute|Minutes|Hour|Hours|Day|Days|Month|Months|Year|Years|Block|Blocks)$/

    if (argv.cron) {
      if (cronExp.test(argv.cron)) {
        tags = [...tags,
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


    // if process type is hyper then lets spawn a process
    // using mainnet for pure hyperbeam aos
    if (ctx.processType === "hyper") {
      if (process.env.AO_URL === "undefined") {
        process.env.AO_URL = "https://forward.computer"
        process.env.SCHEDULER = "NoZH3pueH0Cih6zjSNu_KRAcmg4ZJV1aGHKi0Pi5_Hc"
        process.env.AUTHORITY = "undefined"
      }
      return services.spawnProcessMainnet({
        wallet: jwk,
        src: module,
        tags,
        data,
        isHyper: true
      })
    }


    return services.spawnProcess({
      wallet: jwk,
      src: module,
      tags,
      data
    })
  }

  const alreadyRegistered = async (results) => {
    if (results.length == 1) {
      // this handles the case when a user enters a process name
      // we can check to see if it is a hyper-aos process
      if (process.env.AO_URL === "undefined") {
        const appName = results[0].node.tags.find(t => t.name == "App-Name")?.value || 'aos'
        if (appName === "hyper-aos") {
          process.env.AO_URL = "https://forward.computer"
        }
      }
      return Promise.resolve(results[0].node.id)
    }

    const processes = results.map((r, i) => {
      const version = r.node.tags.find(t => t.name == "aos-Version")?.value
      return {
        title: `${i + 1} - ${version} - ${r.node.id}`,
        value: r.node.id
      }
    })

    return prompts({
      type: 'select',
      name: 'process',
      message: 'Please select a process',
      choices: processes,
      instructions: false
    })
      .then(r => r.process)
      .then(id => {
        // TODO: we need to locate this process and check to see if the process
        // is a hyper-aos process then set the AO_URL if not already set
      })
      .catch(() => Promise.reject({ ok: false, error: 'Error selecting process' }))
  }

  const argv = minimist(process.argv.slice(2))
  const name = argv._[0] || 'default'

  let spawnTags = Array.isArray(argv["tag-name"]) ?
    argv["tag-name"].map((name, i) => ({
      name: String(name || ""),
      value: String(argv["tag-value"][i] || "")
    })) : [];
  if (spawnTags.length === 0 && typeof argv["tag-name"] === "string") {
    spawnTags = [{
      name: String(argv["tag-name"] || ""),
      value: String(argv["tag-value"] || "")
    }]
  }
  if (services.isAddress(name)) {
    return of(name)
  }
  const doRegister = ctx => !ctx.ok ? Rejected(ctx) : findModule(ctx)
    .chain(pickProcessType)
    .chain(createProcess)

  const resolveId = fromPromise(alreadyRegistered)

  return of({ jwk, name, spawnTags, module: argv.module })
    .chain(getAddress)
    .chain(findProcess)
    .bichain(doRegister, resolveId)
    
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
