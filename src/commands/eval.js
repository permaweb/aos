/**
 * eval command
 * 
 * 
 */
import { path } from '../hyper-utils.js'
import { Resolved } from 'hyper-async'

export function evaluate(data, processId, wallet, services) {

  const writeInteraction = (input) => services.writeInteraction({
    contract: processId,
    input,
    wallet
  })

  return writeInteraction({ function: 'eval', data })
    .chain(_ => services.readOutput(processId))
    // temporarly crank messages until bug is fixed in cu
    .chain(res => {
      const msg = res.result.messages[0]
      if (msg) {
        return services.writeInteraction({
          contract: msg.target,
          input: msg.message,
          wallet
        }).map(_ => res)
      }
      return Resolved(res)
    })
    .map(path(['result', 'output']))
}