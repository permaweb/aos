/**
 * create a new account for a given wallet, for this demo only one process per jwk.
 * 
 * register -w ./wallet.json
 * 
 */

import { of, Resolved, Rejected } from 'hyper-async'
import * as utils from '../hyper-utils.js'

const AOS_SRC = process.env.AOS_SRC || "x3j2ilxP81Gob1WKTF6RVLVhFNcGI3LTGxXz7b2Qq4A"

export function register(jwk, services) {

  const getAddress = ctx => services.address(ctx.jwk).map(address => ({ address, ...ctx }))
  const findProcess = ({ jwk, address }) => services.gql(queryForAOS(), { owners: [address] })
    .map(utils.path(['data', 'transactions', 'edges']))
    .chain(results => results.length > 0 ? Resolved(results) : Rejected({ jwk, address }))
  //.chain(results => Rejected({ jwk, address }))

  const createProcess = ({ jwk, address }) => services.createContract({
    wallet: jwk,
    src: AOS_SRC,
    initState: {
      name: 'Personal AOS',
      owner: address,
      env: { logs: [] }
    },
    tags: [
      { name: 'Contract-Type', value: 'ao' },
      { name: 'AOS', value: 'true' }
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
        { name: "Contract-Type", values: ["ao"] },
        { name: "AOS", values: ["true"]},
        { name: "Contract-Src", values: ["${AOS_SRC}"]}
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
