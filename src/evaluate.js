import { fromPromise } from 'hyper-async'

export async function evaluate(line, processId, wallet, services) {
  return services.sendMessage({
    processId: processId,
    wallet: wallet, tags: [
      { name: 'function', value: 'eval' },
      { name: 'expression', value: line }
    ]
  })
    //.chain(_ => fromPromise(() => new Promise((res) => setTimeout(() => res(_), 1000)))())
    .chain(services.readResult)
    .toPromise()
  //return { output: 'echo: ' + line, prompt: null }
}