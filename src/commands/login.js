/**
 * login command
 * 
 * login -w ./wallet.json 
 */
import { of, Resolved, Rejected } from 'hyper-async'
import * as utils from '../hyper-utils.js'


export function login(jwk, services) {
  const getAddress = ctx => services.address(ctx.jwk).map(address => ({ address, ...ctx }))
  const findProcess = ({ jwk, address }) => services.gql(queryForAOS(), { owners: [address] })
    .map(utils.path(['data', 'transactions', 'edges']))
    .chain(results => results.length > 0 ? Resolved(results) : Rejected({ jwk, address }))
    .map(utils.path([0, 'node', 'id']))

  return of({ jwk })
    .chain(getAddress)
    .chain(findProcess)
}

// TODO - add this back
// { name: "Contract-Type", values: ["ao"] },
function queryForAOS() {
  return `query ($owners: [String!]!) {
    transactions(
      first: 1,
      owners: $owners,
      tags: [
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
