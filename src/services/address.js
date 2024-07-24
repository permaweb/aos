import { fromPromise } from 'hyper-async'
import Arweave from 'arweave'

const ARWEAVE_HOST = process.env.ARWEAVE_HOST || 'arweave.net'
const ARWEAVE_PORT = process.env.ARWEAVE_PORT || 443
const ARWEAVE_PROTOCOL = process.env.ARWEAVE_PROTOCOL || 'https'

const arweave = Arweave.init({
  host: ARWEAVE_HOST,
  port: ARWEAVE_PORT,
  protocol: ARWEAVE_PROTOCOL
})

export function address(jwk) {
  return fromPromise(() => arweave.wallets.jwkToAddress(jwk))()
}

export function isAddress(candidate) {
  return (/^([a-zA-Z0-9_-]{43})$/).test(candidate)
}
