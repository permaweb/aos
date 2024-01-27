import { of } from 'hyper-async'
import { map, find } from 'ramda'
import minimist from 'minimist'
import * as utils from '../hyper-utils.js'

const argv = minimist(process.argv.slice(2))
const AOS_MODULE = process.env.AOS_MODULE || argv.module || 'Lx86b7Q1rhfvirf5zaBsYr3sYS6TfDxrG6wHv6QTvoY'

export function list(jwk, services) {
  const getAddress = ctx => services.address(ctx.jwk).map(address => ({ address, ...ctx }))
  const listProcesses = ({ address }) => {
    return services.gql(queryForAOSs(), { owners: [address] })
      .map(utils.path(['data', 'transactions', 'edges']))
  }
  return of({ jwk })
    .chain(getAddress)
    .chain(listProcesses)
    .map(map(({ node }) => find(t => t.name == "Name", node.tags).value || 'undefined'))
    .map(list => `
Your Processes:

${list.join('\n')}
    `)
}

function queryForAOSs() {
  return `query ($owners: [String!]!) {
    transactions(
      first: 1,
      owners: $owners,
      tags: [
        { name: "Data-Protocol", values: ["ao"] },
        { name: "Type", values: ["Process"]},
        { name: "Module", values: ["${AOS_MODULE}"]}
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