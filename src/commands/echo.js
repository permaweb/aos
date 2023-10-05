/**
 * echo command
 * 
 * echo Hello World
 * 
 */
import { path } from '../hyper-utils.js'

export function echo(data, processId, wallet, services) {

  const writeInteraction = (input) => services.writeInteraction({
    contract: processId,
    input,
    wallet
  })

  return writeInteraction({ function: 'echo', data })
    .chain(tx => services.readOutput(processId))
    .map(path(['result', 'output']))
}