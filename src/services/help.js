import chalk from 'chalk'

export function replHelp() {
  console.log(`
${chalk.green('AOS Client Functions')}

${chalk.blue('Documentation:')} https://cookbook_ao.g8way.io

${chalk.green('Client commands:')}

  ${chalk.green('.load [file]')}                  Loads local Lua file into the process
  ${chalk.green('.load-blueprint [blueprint]')}   Loads a blueprint from the blueprints repository
  ${chalk.green('.monitor')}                      Starts monitoring cron messages for this process
  ${chalk.green('.unmonitor')}                    Stops monitoring cron messages for this process
  ${chalk.green('.editor')}                       Simple code editor for writing multi-line Lua expressions
  ${chalk.green('.dryrun')}                       Toggle dryrun mode that sends every command as a dryrun and never saves memory
  ${chalk.green('.exit')}                         Close the client
  ${chalk.green('.help')}                         Print this help screen
  `)
}

export function help() {
  console.log(`
${chalk.green('Welcome to the AOS client! AOS allows you to build and interact with AO processes.')}

${chalk.blue('Full AOS documentation:')} https://cookbook_ao.g8way.io

${chalk.green('Usage:')} aos [name] [options]

${chalk.green('Options:')}

  ${chalk.green('[name]')}                    The name of the process you want to spawn or connect to.
                            If you do not specify a name then "default" will be used.
  ${chalk.green('--wallet [file]')}           Set the wallet to interact with your process. By Default one is created for you at ~/.aos.json
  ${chalk.green('--relay [relay-url]')}       Set the HyperBEAM Relay URL to handle payments in your process.
  ${chalk.green('--watch=[process]')}         Watch the console of a process, even if you are not the owner.
  ${chalk.green('--load [file]')}             Load Lua source file(s) into your process.
  ${chalk.green('--list')}                    Lists the processes for your wallet.
  ${chalk.green('--data [file]')}             Set a file as the data when spawning a new process.
  ${chalk.green('--tag-name [name]')}         Set a tag name for your process when spawning. Pair with --tag-value.
  ${chalk.green('--tag-value [value]')}       Set a tag value for your process when spawning. Pair with --tag-name.
  ${chalk.green('--module=[TXID]')}           The module ID to use when spawning a process.
  ${chalk.green('--cron [frequency]-[unit]')} Setup automated messages for your process for a given interval. For example: 1-minute, 30-second.
  ${chalk.green('--monitor')}                 Monitor and push cron outbox messages and spawns.
  ${chalk.green('--get-blueprints [dir]')}    Download blueprint Lua scripts to your current working directory.
  ${chalk.green('--gateway-url')}             Set Arweave gateway location.
  ${chalk.green('--cu-url')}                  Set Computer Unit location.
  ${chalk.green('--mu-url')}                  Set Messenger Unit location
  ${chalk.green('--sqlite')}                  Spawn AOS process using sqlite3 AOS Module ie [[ aos [name] --sqlite ]]
  ${chalk.green('--version')}                 Show AOS client version number
  ${chalk.green('--help')}                    Shows this help page.
`)

}