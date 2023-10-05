/**
 * eval command
 * 
 * 
 */
import { path } from '../hyper-utils.js'

export function evaluate(data, processId, wallet, services) {

  const writeInteraction = (input) => services.writeInteraction({
    contract: processId,
    input,
    wallet
  })

  return writeInteraction({ function: 'eval', data })
    .chain(tx => services.readOutput(processId))
    .map(path(['result', 'output']))
}