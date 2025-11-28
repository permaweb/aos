// like evaluate but it does not save memory

export async function dryEval(line, processId, wallet, services, spinner) {
  if (process.env.DEBUG) console.time('Send')

  const result = await services.dryrun({
    processId: processId,
    wallet: wallet,
    tags: [
      { name: 'Action', value: 'Eval' }
    ],
    data: line
  }, spinner)

  if (process.env.DEBUG) {
    console.log("")
    console.timeEnd('Send')
  }

  return result
}
