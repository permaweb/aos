import { of, fromPromise, Resolved } from 'hyper-async'
import chalk from 'chalk'

export async function evaluate(line, processId, wallet, services, spinner) {
  return of()
    .map(_ => {
      if (process.env.DEBUG) console.time('send')
      return _
    })
    .chain(() => services.sendMessage({
      processId: processId,
      wallet: wallet, tags: [
        { name: 'Action', value: 'Eval' }
      ],
      data: line
    }, spinner))

    .map(x => {
      //console.log(x)
      if (process.env.DEBUG) {
        console.log("\n")
        console.timeEnd('send')
        console.log("\n")
      }
      spinner.suffixText = `${chalk.gray("[Computing")} ${chalk.green(x)} ${chalk.gray("state transformations]")}`
      if (process.env.DEBUG) console.time('read')
      return x
    })

    .map(message => ({ message, process: processId }))
    .chain(services.readResult)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .map(x => {
      if (process.env.DEBUG) {
        console.log("\n")
        console.timeEnd('read')
        console.log("\n")
      }
      return x
    })
    .toPromise()
  //return { output: 'echo: ' + line, prompt: null }
}