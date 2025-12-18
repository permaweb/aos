import { map, find } from 'ramda'
import minimist from 'minimist'
import * as utils from '../utils/hyper-utils.js'
import { printWithBorder } from '../utils/print.js'
import { chalk } from '../utils/colors.js'

export async function list(jwk, services) {
  const argv = minimist(process.argv.slice(2))

  const address = await services.address(jwk)
  const gqlResult = await services.gql(queryForAOSs(), { owners: [address] })
  const edges = utils.path(['data', 'transactions', 'edges'])(gqlResult)

  const processList = map(({ node }) => {
    const pid = node.id
    const name = find(t => t.name === 'Name', node.tags)?.value
    const version = find(t => t.name.toLowerCase() === 'aos-version', node.tags)?.value
    return `${`${name}`} - ${chalk.green(pid)} ${chalk.gray(`(v${version})`)}`
  }, edges)

  printWithBorder([
    ...processList
  ], {
    title: 'Your Processes',
    borderColor: chalk.gray,
    titleColor: chalk.green,
    truncate: true
  })
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
