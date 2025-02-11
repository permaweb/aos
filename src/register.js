/**
 * create a new account for a given wallet, for this demo only one process per jwk.
 * 
 * register -w ./wallet.json
 * 
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

    return services
      .gql(queryForAOS(name), { owners: [address, argv.address || ""] })
      .map(utils.path(['data', 'transactions', 'edges']))
      .bichain(
        _ => Rejected({ ok: false, error: 'GRAPHQL Error trying to locate process.' }),
        results => results?.length > 0
            ? Resolved(results.reverse())
            /**
             * No process was found that matches the name, module and owners
             * But no catastrophic error occured. 
             * 
             * By rejecting with 'ok: true' we are signaling that a 
             * new process should be spawned with the given criteria
             */
            : Rejected({ ...ctx, ok: true })
      )
  }

  const selectModule = (results) =>
    of(results).chain((results) => {
      if (!results?.length) return Rejected({ ok: false, error: 'No module found with provided name.' })

      return of(results)
        .chain((results) => {
          if (results.length === 1) return Resolved(results[0].node.id)
          return Rejected(results)
        })
        .bichain(fromPromise(promptUser), Resolved)
    })
  

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

  const createProcess = (ctx) => {
    const { ok, name, spawnTags, module, error } = ctx
    if (!ok) {
      return Rejected({ error: error || 'Unknown error occured' })
    }
    let data = "1984"
    let tags = [
      { name: 'App-Name', value: 'aos' },
      { name: 'Name', value: name },
      { name: 'Authority', value: 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY' },
      ...(spawnTags || [])
    ]
    const argv = minimist(process.argv.slice(2))
    if (argv.cron) {
      if (/^\d+\-(second|seconds|minute|minutes|hour|hours|day|days|month|months|year|years|block|blocks|Second|Seconds|Minute|Minutes|Hour|Hours|Day|Days|Month|Months|Year|Years|Block|Blocks)$/.test(argv.cron)) {
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

    return services.spawnProcess({
      wallet: jwk,
      src: module,
      tags,
      data
    })
  }

  const alreadyRegistered = async (results) => {
    if (results.length == 1) {
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

  return of({ jwk, name, spawnTags, module: argv.module })
    .chain(getAddress)
    .chain(findProcess)
    .bichain(
      (ctx) => {
        if (!ctx.ok) return Rejected(ctx)
        return findModule(ctx).chain(createProcess)
      },
      fromPromise(alreadyRegistered)
    )
    
}

// function queryForTransfered(name) {
//   return `query ($recipients: [String!]!) {
//     transactions(
//       first: 100,
//       recipients: $recipients,
//       tags:[
//         { name:"Data-Protocol", values: ["ao"]},
//         { name:"Variant", values:["ao.TN.1"]},
//         { name:"Type", values:["Process-Transfer"]},
//         { name:"Name", values:["${name}"]}
//       ],
//       sort:HEIGHT_ASC
//     ) {
//       edges {
//         node {
//           id
//           tags {
//             name 
//             value 
//           }

//         }
//       }
//     }
//   }
//   `
// }

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
