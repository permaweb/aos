export async function evaluate(line, processId, wallet, services) {
  return services.sendMessage(
    processId,
    wallet, [
    { name: 'Data-Protocol', value: 'ao' },
    { name: 'ao-type', value: 'message' },
    { name: 'function', value: 'eval' },
    { name: 'expression', value: line }
  ])
    .toPromise()
  //.chain(services.readResult)

  //return { output: 'echo: ' + line, prompt: null }
}