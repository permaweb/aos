// import yargs from 'yargs/yargs'
// import { hideBin } from 'yargs/helpers'

import Arweave from 'arweave'
import fs from 'fs'
import path from 'path'
import os from 'os'

export async function getWallet() {
  if (fs.existsSync(path.resolve(os.homedir() + '/.aos.json'))) {
    return JSON.parse(fs.readFileSync(path.resolve(os.homedir() + '/.aos.json'), 'utf-8'))
  }

  let wallet = await Arweave.init({}).wallets.generate()
  fs.writeFileSync(path.resolve(os.homedir() + '/.aos.json'), JSON.stringify(wallet))
  return wallet
}