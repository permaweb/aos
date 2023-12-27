/**
 * create a new account for a given wallet, for this demo only one process per jwk.
 * 
 * register -w ./wallet.json
 * 
 */

import { of, Resolved, Rejected } from 'hyper-async'
import * as utils from './hyper-utils.js'

const AOS_SRC = process.env.AOS_SRC || 'UvGVK5RT6wO9187KxbIwU6xmzXvZOmxj3gIubU8RKbc'

export function register(jwk, services) {
  // TODO: validate with zod

  const getAddress = ctx => services.address(ctx.jwk).map(address => ({ address, ...ctx }))
  const findProcess = ({ jwk, address }) => services.gql(queryForAOS(), { owners: [address] })
    .map(utils.path(['data', 'transactions', 'edges']))
    .bichain(
      _ => Rejected({ jwk, address }),
      results => results.length > 0 ? Resolved(results) : Rejected({ jwk, address })
    )
  //.chain(results => Rejected({ jwk, address }))

  const createProcess = ({ jwk, address }) => services.spawnProcess({
    wallet: jwk,
    src: AOS_SRC,
    tags: [
      { name: 'Name', value: 'Personal AOS' }
    ]
  })
  const alreadyRegistered = results => Resolved(results[0].node.id)

  return of({ jwk })
    .chain(getAddress)
    .chain(findProcess)
    .bichain(createProcess, alreadyRegistered)
}

function queryForAOS() {
  return `query ($owners: [String!]!) {
    transactions(
      first: 1,
      owners: $owners,
      tags: [
        { name: "Data-Protocol", values: ["ao"] },
        { name: "Type", values: ["Process"]},
        { name: "Module", values: ["${AOS_SRC}"]}
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
