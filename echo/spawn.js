const { createDataItemSigner, spawnProcess } = require('@permaweb/ao-sdk')
const fs = require('fs')

const jwk = JSON.parse(fs.readFileSync('./wallet.json', 'utf-8'))
async function main() {
  const processId = await spawnProcess({
    srcId: 'YYHR-dD1yYF7kVpGSB5MnJrmpBUhI0ZCaEPcc9uvax0',
    signer: createDataItemSigner(jwk),
    tags: []
  })

  console.log(processId)

}

main()