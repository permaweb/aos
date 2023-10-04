/**
 * echo command
 * 
 * echo Hello World
 * 
 */
import { of } from 'hyper-async'

export function echo(data, services, processId, wallet) {

  const writeInteraction = (input) => services.writeInteraction({
    contract: processId,
    input,
    wallet
  })

  return writeInteraction({ function: 'echo', data })
    .chain(services.readOutput)
}