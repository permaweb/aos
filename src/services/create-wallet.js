import Arweave from 'arweave'
import fs from 'fs'
import path from 'path'

export async function createWallet() {
  let wallet = await Arweave.init({}).wallets.generate()
  fs.writeFileSync(path.resolve('./aos.json'), JSON.stringify(wallet))
  return wallet
}