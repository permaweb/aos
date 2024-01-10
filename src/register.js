/**
 * create a new account for a given wallet, for this demo only one process per jwk.
 * 
 * register -w ./wallet.json
 * 
 */

import minimist from 'minimist'
import { of, Resolved, Rejected, fromPromise } from 'hyper-async'
import * as utils from './hyper-utils.js'

const AOS_MODULE = process.env.AOS_MODULE || 'EtqW9PTyv3_ir6op9iOPu8TA0G7y6ZYC0o2f6p2DgJ4'

export function register(jwk, services) {
  const getAddress = ctx => services.address(ctx.jwk).map(address => ({ address, ...ctx }))
  const findProcess = ({ jwk, address }) => {
    return services.gql(queryForAOS(), { owners: [address] })
      .map(utils.path(['data', 'transactions', 'edges']))
      .bichain(
        _ => Rejected({ jwk, address }),
        results => results.length > 0 ? Resolved(results) : Rejected({ jwk, address })
      )
  }

  const createProcess = ({ jwk, address }) => {

    let tags = [
      { name: 'App-Name', value: 'aos' }
    ]
    const argv = minimist(process.argv.slice(2))
    if (argv.cron) {
      if (/^\d+\-(seconds|minutes|hours|days|months|years|blocks)$/.test(argv.cron)) {
        tags = [...tags, { name: 'Cron-Interval', value: argv.cron }]
      } else {
        throw Error('Invalid cron flag!')
      }
    }

    return services.spawnProcess({
      wallet: jwk,
      src: AOS_MODULE,
      tags
    })
  }

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
        { name: "Module", values: ["${AOS_MODULE}"]}
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
