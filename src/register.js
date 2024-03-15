/**
 * create a new account for a given wallet, for this demo only one process per jwk.
 * 
 * register -w ./wallet.json
 * 
 */

import { of, Resolved, Rejected, fromPromise } from 'hyper-async'
import * as utils from './hyper-utils.js'
import minimist from 'minimist'
import { getPkg } from './services/get-pkg.js'
import fs from 'fs'
import path from 'path'

export function register(jwk, services) {
  const AOS_MODULE = process.env.AOS_MODULE || getPkg().aos.module
  const getAddress = ctx => services.address(ctx.jwk).map(address => ({ address, ...ctx }))
  const findProcess = ({ jwk, address, name, spawnTags }) => {
    const argv = minimist(process.argv.slice(2))

    return services.gql(queryForAOS(name, AOS_MODULE), { owners: [address, argv.address || ""] })
      .map(utils.path(['data', 'transactions', 'edges']))
      .bichain(
        _ => Rejected({ jwk, address, name, spawnTags }),
        results => results.length > 0 ? Resolved(results) : Rejected({ jwk, address, name, spawnTags })
      )
  }

  const createProcess = ({ jwk, address, name, spawnTags }) => {
    let data = "1984"
    let tags = [
      { name: 'App-Name', value: 'aos' },
      { name: 'Name', value: name },
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
      src: AOS_MODULE,
      tags,
      data
    })
  }

  const alreadyRegistered = results => Resolved(results[0].node.id)
  const argv = minimist(process.argv.slice(2))
  const name = argv._[0] || 'default'

  let spawnTags = Array.isArray(argv["tag-name"]) ?
    argv["tag-name"].map((name, i) => ({
      name,
      value: argv["tag-value"][i]
    })) : [];
  if (spawnTags.length === 0 && typeof argv["tag-name"] === "string") {
    spawnTags = [{ name: argv["tag-name"], value: argv["tag-value"] || "" }]
  }
  if (name.length === 43) {
    return of(name)
  }

  return of({ jwk, name, spawnTags })
    .chain(getAddress)
    .chain(findProcess)
    .bichain(createProcess, alreadyRegistered)

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

function queryForAOS(name, AOS_MODULE) {
  return `query ($owners: [String!]!) {
    transactions(
      first: 1,
      owners: $owners,
      tags: [
        { name: "Data-Protocol", values: ["ao"] },
        { name: "Type", values: ["Process"]},
        { name: "Module", values: ["${AOS_MODULE}", "1SafZGlZT4TLI8xoc0QEQ4MylHhuyQUblxD8xLKvEKI", "9afQ1PLf2mrshqCTZEzzJTR2gWaC9zNPnYgYEqg1Pt4"]},
        { name: "Name", values: ["${name}"]}
      ]
    ) {
      edges {
        node {
          id
        }
      }
    }
  }`
}
