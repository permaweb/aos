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
  // parse error message
  const errorMessage = error.replace(
    /\[string "[a-zA-Z0-9_.-]*"\]:[0-9]*: /g,
    ''
  )

  // parse line number
  const lineNumbers = error.match(/:([0-9]*):/g)
  if (!lineNumbers) return undefined

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

  for (let i = 0; i < loadedModules.length; i++) {
    // get module line count
    const lineCount = (loadedModules[i].content.match(/\r?\n/g)?.length || 0) + 1

    if (currentLine + lineCount >= lineNumber) {
      return {
        file: loadedModules[i].path,
        line: lineNumber - currentLine - i * 2
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

  console.log(
    chalk.bold(chalk.red('error') + ': ' + error.errorMessage) +
    '\n' +
    (origin ? chalk.dim(`  in ${origin.file}\n`) : "") +
    chalk.blue(` ${lineNumberPlaceholder} |\n ${lineNumber} |    `) +
    line.split('\n')[error.lineNumber - 1] +
    '\n' +
    chalk.blue(` ${lineNumberPlaceholder} |\n`) +
    chalk.dim('This error occurred while aos was evaluating the submitted code.')
  )
}
