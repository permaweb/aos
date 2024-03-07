import chalk from 'chalk'

export function replHelp() {
  console.log(`
${chalk.green('aos Console')}

${chalk.blue('Documentation:')} https://cookbook_ao.g8way.io

${chalk.green('Commands:')}

  ${chalk.green('.load [file]')}                  Loads local lua file into connected Process
  ${chalk.green('.load-blueprint [blueprint]')}   Loads a blueprint from the blueprints repository
  ${chalk.green('.monitor')}                      Starts monitoring cron messages for this Process
  ${chalk.green('.unmonitor')}                    Stops monitoring cron messages for this Process
  ${chalk.green('.editor')}                       Simple code editor for writing multi-line lua expressions
  ${chalk.green('.help')}                         Print this help screen
  ${chalk.green('.exit')}                         Quit console
  `)
}

export function help() {
  console.log(`
${chalk.green('aos Console')}

${chalk.blue('Documentation:')} https://cookbook_ao.g8way.io

${chalk.green('Usage:')} aos [name] [OPTIONS]

${chalk.green('Options:')}

  ${chalk.green('--get-blueprints [dir]')}   Download Blueprint Lua Scripts to your current working directory
  ${chalk.green('--cron [Interval]')}        Setup automated messages for your process for a given interval ie (1-minute, 5-minutes)
  ${chalk.green('--load [file]')}            Load a lua source file into your process more than 1 is supported
  ${chalk.green('--data [file]')}            Load a data file when creating process
  ${chalk.green('--tag-name [name]')}        Tag Name for Process when Spawn more than 1 is supported
  ${chalk.green('--tag-value [value]')}      Tag Value for Process when Spawning grouped with tag-name
  ${chalk.green('--wallet [file]')}          Wallet to use for Process Managment a default wallet is created for you.
  ${chalk.green('--module=[TXID]')}          The module source to use to spin up Process
  ${chalk.green('--list')}                   Lists the processes for a given wallet
  ${chalk.green('--watch=[PROCESSID]')}.     Watch a process
  ${chalk.green('--monitor')}.               Monitor and Push Cron Outbox Messages and Spawns
  ${chalk.green('--help')}                   Shows help page
  ${chalk.green('--version')}                Shows Console Version

${chalk.green('name')}                       Name is the Process name you want to spawn or connect to, if you do not
                           specify a name then "default" will be used.
`)

}