import { config } from '../config.js'

const ARWEAVE_GRAPHQL =
  process.env.ARWEAVE_GRAPHQL ||
  (process.env.GATEWAY_URL ? new URL('/graphql', process.env.GATEWAY_URL) : config.urls.GATEWAY)

export async function gql(query, variables) {
  const body = { query, variables }

  const res = await fetch(ARWEAVE_GRAPHQL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  })

  if (!res.ok) {
    throw new Error(`(${res.status}) ${res.statusText} - GQL ERROR`)
  }

  const result = await res.json()

  if (result.data === null) {
    throw new Error(`GQL ERROR - No data returned`)
  }

  return result
}
