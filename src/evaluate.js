import { fromPromise, Resolved } from 'hyper-async'
import chalk from 'chalk'

export async function evaluate(line, processId, wallet, services, spinner) {
  return services.sendMessage({
    processId: processId,
    wallet: wallet, tags: [
      { name: 'Action', value: 'Eval' }
    ],
    data: line
  })
    .map(x => {
      spinner.suffixText = `${chalk.gray("[Computing")} ${chalk.green(x)} ${chalk.gray("state transformations]")}`
      return x
    })

    .map(message => ({ message, process: processId }))
    .chain(services.readResult)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .bichain(services.readResult, Resolved)
    .toPromise()
  //return { output: 'echo: ' + line, prompt: null }
}