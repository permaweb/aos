import Arweave from 'arweave'
import fs from 'fs'
import path from 'path'
import os from 'os'

export async function createWallet() {
  let wallet = await Arweave.init({}).wallets.generate()
  fs.writeFileSync(path.resolve(os.homedir() + '/.aos.json'), JSON.stringify(wallet))
  return wallet
}