/**
 * create a new account for a given wallet, for this demo only one process per jwk.
 * 
 * register -w ./wallet.json
 * 
 */
import fs from 'fs'
import path from 'path'

export function register(args) {
  const jwk = JSON.parse(fs.readFileSync(path.resolve(args.w)))

  return of(jwk)
    .chain(getAddress) // get address
    .chain(findProcess) // check if wallet has process
    .bichain(createProcess, identity) // if no process create process

}