/**
 * login command
 * 
 * login -w ./wallet.json 
 */
import fs from 'fs'
import path from 'path'
import { of } from 'hyper-async'

export function login(args, services) {
  try {
    const jwk = JSON.parse(fs.readFileSync(path.resolve(args.w), 'utf-8'))
    return of(jwk)
    //   .chain(findProcess)
    //return "Login Called"
  } catch (e) {
    return "ERROR: JWK Wallet File is required!"
  }
}