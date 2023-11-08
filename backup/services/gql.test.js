import test from 'node:test'
import assert from 'assert/strict'

test('Run GraphQL', async () => {
  const { gql } = await import('./gql.js')
  const result = await gql(`query ($owners: [String!]!) {
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
  }`, { owners: ["vh-NTHVvlKZqRxc8LyyTNok65yQ55a_PJ1zWLb9G2JI"] }).toPromise()
  console.log(result)
  assert.ok(true)
})