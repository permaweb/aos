import Bundlr from '@bundlr-network/client'
import fs from 'fs'

async function publish() {
  const wallet = JSON.parse(fs.readFileSync('./wallet.json', 'utf-8'))
  const bundlr = new Bundlr("https://node2.bundlr.network", "arweave", wallet)
  const tags = [
    { name: 'Content-Type', value: 'application/wasm' },
    { name: 'App-Name', value: 'SmartWeaveContractSource' },
    { name: 'App-Version', value: '0.4.0' },
    { name: 'Contract-Type', value: 'ao' }
  ]
  const result = await bundlr.uploadFile('./contract/contract.wasm', { tags })
  console.log(result)
}

publish()