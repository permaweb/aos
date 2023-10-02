import repl from 'repl'

console.log(`
ARbit CLI - 0.1
2023 - [CTRL-D] to exit


`)

let loggedIn = false

function doCommand(uInput, context, filename, callback) {
  // if (!loggedIn) {
  //   callback(null, 'Login is required!')
  //   return
  // }
  callback(null, "Got It...")
}

let { context } = repl.start({ prompt: 'arbit :) ', eval: doCommand })

context.beep = 'boop'