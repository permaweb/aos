/**
 * Evaluate.js
 *
 * This module exports the `evaluate` function, which processes a given input 
 * line by asynchronously sending it to a Hyperbeam or legacy Mu service and 
 * retrieving the computed result. It employs functional programming 
 * constructs from `hyper-async` to manage asynchronous flows effectively. 
 * Utility functions handle spinner updates, debugging logs, error handling,
 * and conditional result fetching to streamline interactions with external services.
 */

import { of, fromPromise, Resolved } from 'hyper-async'
import chalk from 'chalk'

export async function evaluate(line, processId, wallet, services, spinner) {
  return of({ processId, wallet, tags: [{ name: 'Action', value: 'Eval' }], data: line })
    .map(tStart('Send'))
    .chain(pushMessage)
    .map(tEnd('Send'))
    .map(changeSpinner)
    .map(tStart('Read'))
    .chain(readResult)
    .map(tEnd('Read'))
    .toPromise().catch(logError)

  // send message to hyperbeam or legacy mu
  function pushMessage(msg) {
    return services.sendMessage(msg, spinner)
  }

  // read the result unless it is provided.
  function readResult(message) {
    return message.Output || message.Error
    ? of(message)
    : services.readResult({ message, process: processId })
  }

  // change spinner description
  function changeSpinner(ctx) {
    spinner.suffixText = `${chalk.gray("[Computing")} ${chalk.green(ctx)}${chalk.gray("...]")}`
    return ctx
  }
  // common time start console tap function
  function tStart(name) {
    return _ => {
      if (process.env.DEBUG) {
        console.time(name)
      }
      return _
    }
  }

  // common time end console tap function
  function tEnd(name) {
    return _ => {
      if (process.env.DEBUG) {
        console.log("\n>>>>>>>>>")
        console.timeEnd(name)
        console.log(">>>>>>>>>\n")
      }
      return _
    }
  }
  
  // log error of promise return empty obj
  function logError(err) {
    console.log(err)
    return {}
  }
}
