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

${chalk.green('name')}                       The name of the process that you want to spawn or connect to.
                           If you do not specify a name, the value "default" is used.

${chalk.green('Options:')}

  ${chalk.green('--cron [interval]')}        Set up automated messages for your process, at an interval (e.g. 1-minute, 5-minutes).
  ${chalk.green('--data [file]')}            Load a Lua script when creating a new process.
  ${chalk.green('--get-blueprints')}         Export the standard blueprint Lua scripts to your current working directory.
  ${chalk.green('--help')}                   Displays this help page.
  ${chalk.green('--list')}                   Lists the spawned processes for a given wallet.
  ${chalk.green('--load [file]')}            Load a Lua script into your process. Can be specified multiple times.
                           If you do not specify a file, then the Lua script will be read from ${chalk.green('stdin')}.
  ${chalk.green('--module [txid]')}          The Arweave tx id with the module source to use when spawning a new process.
  ${chalk.green('--monitor')}                Monitor and push cron outbox messages and spawns.
  ${chalk.green('--quiet')}                  Do not print the ${chalk.green('aos')} splashscreen or version information. Useful for CLI scripts.
  ${chalk.green('--sequential')}             Do not combine multiple ${chalk.green('--load')} files into a single batch.
  ${chalk.green('--tag-name [name]')}        Specify a tag to define when spawning a new process. Paired with a ${chalk.green('--tag-value')}.
  ${chalk.green('--tag-value [value]')}      The value of the tag. Paired with a ${chalk.green('--tag-name')}.
                           Multiple ${chalk.green('--tag-name')} and ${chalk.green('--tag-value')} are supported. Always use them in pairs.
  ${chalk.green('--version')}                Print the ${chalk.green('aos')} version information.
  ${chalk.green('--wallet [file]')}          Use this wallet for process management.
                           If you do not specify a wallet, ${chalk.green('.aos.json')} from your home directory is used.
                           If ${chalk.green('.aos.json')} does not exist, it will be created for you.
  ${chalk.green('--watch [processId]')}      Watch a process.
`)
}
