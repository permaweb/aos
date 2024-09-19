// like evaluate but it does not save memory
import { of } from 'hyper-async'

export async function dryEval(line, processId, wallet, services, spinner) {
  return of()
    .map(_ => {
      if (process.env.DEBUG) console.time('Send')
      return _
    })
    .chain(() => services.dryrun({
      processId: processId,
      wallet: wallet, 
      tags: [
        { name: 'Action', value: 'Eval' }
      ],
      data: line
    }, spinner))

    // .map(x => {
    //   //console.log(x)
    //   if (process.env.DEBUG) {
    //     console.log("")
    //     console.timeEnd('Send')
    //   }
    //   spinner.suffixText = `${chalk.gray("[Computing")} ${chalk.green(x)}${chalk.gray("...]")}`
    //   if (process.env.DEBUG) console.time('Read')
    //   return x
    // })


    .map(x => {
      if (process.env.DEBUG) {
        console.log("")
        console.timeEnd('Send')
      }
      return x
    })
    .toPromise()
  //return { output: 'echo: ' + line, prompt: null }
}