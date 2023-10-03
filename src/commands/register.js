/**
 * create a new account for a given wallet, for this demo only one process per jwk.
 * 
 * register -w ./wallet.json
 * 
 */
import fs from 'fs'
import path from 'path'
import { of, Resolved } from 'hyper-async'
import * as utils from '../hyper-utils.js'

export function register(args, services) {
  const getAddress = ctx => services.address(ctx.jwk).map(address => ({ address, ...ctx }))
  const findProcess = ({ jwk, address }) => services.gql(queryForAOS(), { owners: [address] })
    .map(utils.path(['data', 'transactions', 'edges']))
    .chain(results => results.length > 0 ? Resolved(results) : Rejected(results))
  const createProcess = ({ jwk, address }) => services.createContract({
    wallet: jwk,
    src: AOS_SRC,
    initialState: {
      name: 'Personal AOS',
      owner: address
    },
    tags: [{ name: 'AOS', value: 'true' }]
  })

  try {
    const jwk = JSON.parse(fs.readFileSync(path.resolve(args.w), 'utf-8'))

    return of({ jwk })
      .chain(getAddress)
      .chain(findProcess)
      .bichain(() => createProcess(jwk), _ => Resolved('Already Registered!'))
  } catch (e) {
    return "ERROR: JWK Wallet File is required!"
  }
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
