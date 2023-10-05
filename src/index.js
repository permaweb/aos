import repl from 'repl'
import yargs from 'yargs/yargs'
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


console.log(`
AOS CLI - 0.1
2023 - [CTRL-D] to exit


`)

// init business rules
const cmds = commands.init({ gql, address, createContract, writeInteraction, readOutput })

async function doCommand(uInput, context, filename, callback) {
  const argv = yargs(uInput).argv
  const command = argv._[0]
  let jwk = null

  if (['register', 'login'].includes(command)) {
    try {
      jwk = JSON.parse(fs.readFileSync(path.resolve(argv.w), 'utf-8'))
      context.jwk = jwk
    } catch (e) {
      return callback(null, 'Wallet not valid!')
    }
  }

  if (command === 'register') {
    const output = await cmds.register(jwk)
      .map(contractId => {
        context.contract = contractId
        return `Personal AOS Process Created: ${contractId}`
      }).toPromise()
    return callback(null, output)
  }

  if (command === 'login') {
    if (context.contract) {
      return callback(null, 'Already Logged In.')
    }
    const output = await cmds.login(jwk)
      .map(contract => {
        context.contract = contract
        return `Logged into process: ${contract}`
      })
      .toPromise()
    return callback(null, output)
  }

  if (command === "logout") {
    if (!context.contract) {
      callback(null, 'Not Logged in')
      return
    }
    context.contract = null
    context.jwk = null
    callback(null, 'Logged Out!')
    return
  }

  if (context.contract && command === "echo") {

    const output = await cmds.echo(argv._.splice(1).join(' '), context.contract, context.jwk)
      .toPromise()
    callback(null, output)
    return
  }

  if (context.contract && command === "eval") {
    const output = await cmds.evaluate(argv._.splice(1).join(' '), context.contract, context.jwk)
      .toPromise()
    callback(null, output)
    return
  }

  callback(null, "Command not found!")
}

let { context } = repl.start({ prompt: 'aos> ', eval: doCommand })
