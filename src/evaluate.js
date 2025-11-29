/**
 * Evaluate.js
 *
 * This module exports the `evaluate` function, which processes a given input
 * line by asynchronously sending it to a Hyperbeam or legacy Mu service and
 * retrieving the computed result. Uses async/await for clearer control flow.
 */

import { chalk } from './utils/colors.js'

export async function evaluate(line, processId, wallet, services, spinner, swallowError = false) {
  try {
    const msg = { processId, wallet, tags: [{ name: 'Action', value: 'Eval' }], data: line }

    // Send message
    if (process.env.DEBUG) console.time('Send')
    const messageId = await services.sendMessage(msg, spinner)

    if (process.env.DEBUG) {
      console.log('\n>>>>>>>>>')
      console.timeEnd('Send')
      console.log('>>>>>>>>>\n')
    }

    // Update spinner
    spinner.suffixText = `${chalk.gray('[Computing')} ${chalk.green(messageId)}${chalk.gray('...]')}`

    // Read result if not already provided
    if (process.env.DEBUG) console.time('Read')
    const result =
      messageId?.Output || messageId?.Error
        ? messageId
        : await services.readResult({ message: messageId, process: processId })

    if (process.env.DEBUG) {
      console.log('\n>>>>>>>>>')
      console.timeEnd('Read')
      console.log('>>>>>>>>>\n')
    }

    return result
  } catch (err) {
    if (!swallowError) console.log(err)
    return {}
  }
}
