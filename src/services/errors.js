import chalk from 'chalk'
import path from 'path'

/**
 * @typedef AOSError
 * @property {number} lineNumber
 * @property {string} errorMessage
 */

/**
 * Parse an error result string
 * @param {string} error Error result
 * @returns {AOSError}
 */
export function parseError(error) {
  // if we have not been given any error information, return a generic message
  if (!error || Object.keys(error).length === 0) {
    return { lineNumber: 0, errorMessage: "No message given by process." }
  }

  // parse error message
  const errorMessage = error.replace(
    /\[string "[a-zA-Z0-9_.-]*"\]:[0-9]*: /g,
    ''
  )

  // parse line number
  const lineNumbers = error.match(/:([0-9]*):/g)
  if (!lineNumbers) return undefined
  if (lineNumbers.length === 1) {
    const lineNumber = parseInt(errorMessage.match(/(?<=at line )[0-9]+/g) || 1)

    return {
      lineNumber,
      errorMessage
    }
  }

  // (it's going to be the last ":linenumber:")
  const lineNumber = parseInt(lineNumbers[lineNumbers.length - 1].replace(/:/g, ''))

  return {
    lineNumber,
    errorMessage
  }
}

/**
 * @typedef ErrorOrigin
 * @property {string} file
 * @property {number|undefined} line
 */

/**
 * Get error origin file and actual line number
 * @param {Module[]} loadedModules 
 * @param {number} lineNumber
 * @returns {ErrorOrigin|undefined}
 */
export function getErrorOrigin(loadedModules, lineNumber) {
  if (!loadedModules) return undefined
  if (loadedModules.length === 1) {
    return {
      file: loadedModules[0].path,
      line: undefined
    }
  }

  let currentLine = 0

  for (let i = 0; i < loadedModules.length; i++) {
    // get module line count, add 2 for '\n\n' offset
    const lineCount = (loadedModules[i].content.match(/\r?\n/g)?.length || 0) + 1 + 2
    if (currentLine + lineCount >= lineNumber) {
      return {
        file: loadedModules[i].path,
        line: lineNumber - currentLine - (i + 1) * 2
      }
    }

    currentLine += lineCount
  }

  return undefined
}

/**
 * Format and output an error coming from an evaluation
 * @param {string} line
 * @param {AOSError} error
 * @param {ErrorOrigin|undefined} origin
 */
export function outputError(line, error, origin) {
  const lineNumber = origin?.line || error.lineNumber
  const lineNumberPlaceholder = ' '.repeat(lineNumber.toString().length)

  if (origin) {
    console.log(
      '\n' +
      chalk.bold(error.errorMessage) +
      '\n' +
      (origin ? chalk.dim(`  in ${origin.file}\n`) : "") +
      chalk.blue(` ${lineNumberPlaceholder} |\n ${lineNumber} |    `) +
      // Add 2 lines back as the line does not includes the '\n\n' offset
      line.split('\n')[error.lineNumber - 1 + 2] +
      '\n' +
      chalk.blue(` ${lineNumberPlaceholder} |\n`) +
      chalk.dim('This error occurred while aos was evaluating the submitted code.')
    )
  } else {
    console.log(
      '\n' +
      chalk.bold(`Error on line ${lineNumber}: ${error.errorMessage}`) +
      '\n' +
      chalk.dim('This error occurred while aos was evaluating the submitted code.')
    )
  }
}
