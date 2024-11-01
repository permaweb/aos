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
 * @property {string|undefined} lineContent
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
      line: lineNumber - 2, // Remove the \n\n offset
      lineContent: loadedModules[0].content.split('\n')[lineNumber - 2 - 1]
    }
  }

  // Each loaded module begins with \n\n.
  // After the first module, the first '\n' will be appended on the end of the previous module,
  // creating net one new line. However, for the first module, there is no previous module,
  // and two new lines are created. This is why we begin at one and offset by one per module.
  let currentLine = 1

  for (let i = 0; i < loadedModules.length; i++) {
    const lineCount = (loadedModules[i].content.match(/\r?\n/g)?.length || 0) + 2
    /**
     * All modules have 2 lines ('\n\n') prepended to their executable.
     * 
     * Secondary modules have the following content:
     * 
      1  -- module: ".*name*"
      2  local function _loaded_mod_*name*()
          *** function ***
      3  end
      4
      5 '_G.package.loaded[".*name*"] = _loaded_mod_*name*()'

     * (see loading-files.js)
     * This adds 5 lines to the loaded module.
     * The loaded modules will always appear first in the array (ie the main module will be last)
     */
    
    const isPrimaryModule = i == loadedModules.length - 1
    if (currentLine + lineCount >= lineNumber) {
      const originLineNumber = lineNumber - currentLine
      return {
        file: loadedModules[i].path,
        line: originLineNumber - (isPrimaryModule ? 1 : 3), // If secondary module, adjust for added header
        lineContent: loadedModules[i].content.split('\n')[originLineNumber - 2]
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
  const lineNumber = (origin?.line || error.lineNumber)
  const lineContent = (origin?.lineContent || line.split('\n')[lineNumber - 1])
  const lineNumberPlaceholder = ' '.repeat(lineNumber.toString().length)

  console.log(
    '\n' +
    chalk.bold(error.errorMessage) +
    '\n' +
    (origin ? chalk.dim(`  in ${origin.file}\n`) : "") +
    chalk.blue(` ${lineNumberPlaceholder} |\n ${lineNumber} |    `) +
    lineContent +
    '\n' +
    chalk.blue(` ${lineNumberPlaceholder} |\n`) +
    chalk.dim('This error occurred while aos was evaluating the submitted code.')
  )
}
