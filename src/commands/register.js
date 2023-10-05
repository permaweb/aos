/**
 * create a new account for a given wallet, for this demo only one process per jwk.
 * 
 * register -w ./wallet.json
 * 
 */

import { of, Resolved, Rejected } from 'hyper-async'
import * as utils from '../hyper-utils.js'

const AOS_SRC = process.env.AOS_SRC || "Yb9eE8Aog7Yhhc1dSzOItjYUL0oTwgTGsKN_Zx7d0u8"

export function register(jwk, services) {

  const getAddress = ctx => services.address(ctx.jwk).map(address => ({ address, ...ctx }))
  const findProcess = ({ jwk, address }) => services.gql(queryForAOS(), { owners: [address] })
    .map(utils.path(['data', 'transactions', 'edges']))
    //.chain(results => results.length > 0 ? Resolved(results) : Rejected({ jwk, address }))
    .chain(results => Rejected({ jwk, address }))

  const createProcess = ({ jwk, address }) => services.createContract({
    wallet: jwk,
    src: AOS_SRC,
    initState: {
      name: 'Personal AOS',
      owner: address
    },
    tags: [
      { name: 'Contract-Type', value: 'ao' },
      { name: 'AOS', value: 'true' }
    ]
  })
  const alreadyRegistered = _ => Resolved('Already Registered!')

  return of({ jwk })
    .chain(getAddress)
    .chain(findProcess)
    .bichain(createProcess, alreadyRegistered)
}

function queryForAOS() {
  return `query ($owners: [String!]!) {
    transactions(
      owners: $owners,
      tags: [
        { name: "Contract-Type", values: ["ao"] },
        { name: "AOS", values: ["true"]}
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
