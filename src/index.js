import repl from 'repl'
import yargs from 'yargs/yargs'

// services 
import { gql } from './services/gql.js'
import { address } from './services/address.js'

// commands
import * as commands from './commands/index.js'


console.log(`
ARbit CLI - 0.1
2023 - [CTRL-D] to exit


`)

let loggedIn = false

async function doCommand(uInput, context, filename, callback) {
  const argv = yargs(uInput).argv
  const command = argv._[0]

  // init business rules
  const cmds = commands.init({ gql, address })

  if (command === 'register') {
    const output = await cmds.register(argv)
    return callback(null, output)
  }


  // if (command === 'login') {
  //   return callback(null, login(argv))
  // }


  // if (!loggedIn) {
  //   callback(null, 'Login is required!')
  //   return
  // }
  callback(null, "Got It...")
}

let { context } = repl.start({ prompt: 'arbit :) ', eval: doCommand })

context.beep = 'boop'