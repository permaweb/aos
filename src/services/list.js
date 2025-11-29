import { map, find } from 'ramda'
import minimist from 'minimist'
import * as utils from '../hyper-utils.js'
import { getPkg } from './get-pkg.js'

export async function list(jwk, services) {
  const argv = minimist(process.argv.slice(2))
  const AOS_MODULE = process.env.AOS_MODULE || argv.module || getPkg().aos.module

  const address = await services.address(jwk)
  const gqlResult = await services.gql(queryForAOSs(), { owners: [address] })
  const edges = utils.path(['data', 'transactions', 'edges'], gqlResult)

  const processList = map(({ node }) => {
    const pid = node.id
    const name = find(t => t.name == 'Name', node.tags)?.value
    const version = find(t => t.name == 'aos-Version', node.tags)?.value
    return `${name}:v${version || 'unknown'} - ${pid}`
  }, edges)

  return `
  Your Processes:

  ${processList.join('\n  ')}
      `
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
