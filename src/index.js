import repl from 'repl'
import yargs from 'yargs/yargs'

// services 
import { gql } from './services/gql.js'
import { address } from './services/address.js'
import { createContract } from './services/create-contract.js'

// commands
import * as commands from './commands/index.js'


console.log(`
AOS CLI - 0.1
2023 - [CTRL-D] to exit


`)

let loggedIn = false

async function doCommand(uInput, context, filename, callback) {
  const argv = yargs(uInput).argv
  const command = argv._[0]

  // init business rules
  const cmds = commands.init({ gql, address, createContract })

  if (command === 'register') {
    const output = await cmds.register(argv)
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
    return callback(null, cmds.login(argv))
  }

  if (command === "logout") {
    if (!context.contract) {
      callback(null, 'Not Logged in')
      return
    }
    context.contract = null
    callback(null, 'Logged Out!')
    return
  }

  if (context.contract && command === "echo") {
    const output = await cmds.echo(argv, contract)
      .toPromise()
    callback(null, output)
    return
  }

  if (context.contract && command === "eval") {
    const output = await cmds.eval(argv, contract)
      .toPromise()
    callback(null, output)
    return
  }

  callback(null, "Command not found!")
}

let { context } = repl.start({ prompt: 'arbit :) ', eval: doCommand })
