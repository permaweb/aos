import { of, fromPromise, Resolved } from 'hyper-async'
import chalk from 'chalk'

export async function evaluate(line, processId, wallet, services, spinner) {
  return of()
    .map(_ => {
      if (process.env.DEBUG) console.time('Send')
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
        console.log("")
        console.timeEnd('Send')
      }
      spinner.suffixText = `${chalk.gray("[Computing")} ${chalk.green(x)}${chalk.gray("...]")}`
      if (process.env.DEBUG) console.time('Read')
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
        console.log("")
        console.timeEnd('Read')
      }
      return x
    })
    .toPromise().catch(err => {
      console.log(err)
      return {}
    })
  //return { output: 'echo: ' + line, prompt: null }
}