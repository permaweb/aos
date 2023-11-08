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
    .chain(
      // TODO: Implement a merge function that composes bundlr, arweave.net and goldsky.
      //all(
      //queryBundlr,
      queryArweave,
      //queryGoldsky
      //)
      // .chain(mergeAll)
    )
}

const ARWEAVE_GRAPHQL = process.env.ARWEAVE_GRAPHQL || 'https://arweave.net/graphql'
function queryArweave(body) {
  return fromPromise(() => fetch(ARWEAVE_GRAPHQL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  }).then(res => res.json())
  )()
}