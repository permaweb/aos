import { fromPromise } from 'hyper-async'
import chalk from 'chalk'

export async function evaluate(line, processId, wallet, services, spinner) {
  return services.sendMessage({
    processId: processId,
    wallet: wallet, tags: [
      { name: 'function', value: 'eval' },
      { name: 'expression', value: line }
    ]
  })
    .map(x => {
      spinner.suffixText = `${chalk.gray("[Computing")} ${chalk.green(x)} ${chalk.gray("state transformations]")}`
      return x
    })
    .chain(_ => fromPromise(() => new Promise((res) => setTimeout(() => res(_), 1000)))())
    .chain(services.readResult)

    .toPromise()
  //return { output: 'echo: ' + line, prompt: null }
}