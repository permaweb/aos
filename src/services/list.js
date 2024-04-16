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
    return services.gql(queryForAOSs(), { owners: [address] })
      .map(utils.path(['data', 'transactions', 'edges']))
    //.map(_ => (console.log(JSON.stringify(_, null, 2)), _))
  }
  return of({ jwk })
    .chain(getAddress)

    .chain(listProcesses)

    .map(map(({ node }) => {
      const pid = node.id
      const name = find(t => t.name == "Name", node.tags)?.value
      const version = find(t => t.name == "aos-Version", node.tags)?.value
      return `${name}:v${version || 'unknown'} - ${pid}`
    }))
    .map(list => `
  Your Processes:

  ${list.join('\n  ')}
      `)
}

function queryForAOSs() {
  return `query ($owners: [String!]!) {
    transactions(
      first: 100,
      owners: $owners,
      tags: [
        { name: "Data-Protocol", values: ["ao"] },
        { name: "Type", values: ["Process"]}
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
