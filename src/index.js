import repl from 'repl'
import yargs from 'yargs/yargs'
import { hideBin } from 'yargs/helpers'

import fs from 'fs'
import path from 'path'

// services 
import { gql } from './services/gql.js'
import { address } from './services/address.js'
import { createContract } from './services/create-contract.js'
import { writeInteraction } from './services/write-interaction.js'
import { readOutput } from './services/read-output.js'

// commands
import * as commands from './commands/index.js'

// init business rules
const cmds = commands.init({ gql, address, createContract, writeInteraction, readOutput })

async function doCommand(uInput, context, filename, callback) {

  const output = await cmds.evaluate(uInput, context.contract, context.jwk)
    .toPromise()
  callback(null, output)
}

let args = yargs(hideBin(process.argv)).argv

if (!args._[0]) {
  console.log('AOS ERROR: arweave wallet file is required!')
  process.exit(0)
}
let jwk = null

try {
  jwk = JSON.parse(fs.readFileSync(path.resolve(args._[0]), 'utf-8'))
} catch (e) {
  console.log('AOS ERROR: could not parse file!')
  process.exit(0)
}

let contract = "";

cmds.register(jwk)
  .map(contractId => {
    contract = contractId
    return `Personal AOS Process: ${contractId}`
  }).toPromise()
  .then(x => {
    console.log(x)

    console.log(`
AOS CLI - 0.1
2023 - [CTRL-D] to exit

`)
    let { context } = repl.start({ prompt: 'aos> ', eval: doCommand })
    context.jwk = jwk
    context.contract = contract
  })



