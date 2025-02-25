/**
gql service

This service should call the following graphql services and wire them together

* node2.bundlr.network/graphql
* arweave.net/graphql
* arweave-search.goldsky.com/graphql
*/

import { of, fromPromise } from 'hyper-async'


export function gql(query, variables) {
  return of({ query, variables })
    .chain(queryArweave)
}

const ARWEAVE_GRAPHQL = process.env.ARWEAVE_GRAPHQL || (
  process.env.GATEWAY_URL ? new URL('/graphql', process.env.GATEWAY_URL) : 'https://arweave.net/graphql'
)
function queryArweave(body) {
  return fromPromise(() => {
    return fetch(ARWEAVE_GRAPHQL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    })
      .then(res => {
        if (!res.ok) {
          throw new Error(`(${res.status}) ${res.statusText} - GQL ERROR`)
        }
        return res
      })
      .then(result => {
        if (result.data === null) {
          throw new Error(`(${result.status}) ${result.statusText} - GQL ERROR`)
        }
        return result
      })
      .then(async res => {
        const json = await res.json()
        // Catch errors from the gateway (timeouts, etc return a 200 ok)
        if (!json.data && json.errors) {
          throw new Error(`(${json.errors[0].message}) - GQL ERROR`)
        }
        return json
      })

    }
  )()
}