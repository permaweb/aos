import { of } from 'hyper-async'
import { map, find } from 'ramda'
import minimist from 'minimist'
import * as utils from '../hyper-utils.js'
import { getPkg } from './get-pkg.js'

export function list(jwk, services) {
  const argv = minimist(process.argv.slice(2))
  const AOS_MODULE = process.env.AOS_MODULE || argv.module || getPkg().aos.module

  const getAddress = ctx => services.address(ctx.jwk).map(address => ({ address, ...ctx }))
  const listProcesses = ({ address }) => {
    return services.gql(queryForAOSs(), { owners: [address], module: [AOS_MODULE, "1SafZGlZT4TLI8xoc0QEQ4MylHhuyQUblxD8xLKvEKI", "9afQ1PLf2mrshqCTZEzzJTR2gWaC9zNPnYgYEqg1Pt4"] })
      .map(utils.path(['data', 'transactions', 'edges']))
    //.map(_ => (console.log(JSON.stringify(_, null, 2)), _))
  }
  return of({ jwk })
    .chain(getAddress)

    .chain(listProcesses)

    .map(map(({ node }) => {
      const name = find(t => t.name == "Name", node.tags)?.value
      const version = find(t => t.name == "aos-Version", node.tags)?.value
      return `${name}:v${version || 'unknown'}`
    }))
    .map(list => `
  Your Processes:

  ${list.join('\n  ')}
      `)
}

function queryForAOSs() {
  return `query ($owners: [String!]!, $module: [String!]!) {
    transactions(
      first: 100,
      owners: $owners,
      tags: [
        { name: "Data-Protocol", values: ["ao"] },
        { name: "Type", values: ["Process"]},
        { name: "Module", values: $module}
      ]
    ) {
      edges {
        node {
          id
          owner { address }
          tags {
            name
            value
          }
        }
      }
    }
  }`
}