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
  const lineNumber = parseInt(lineNumbers[lineNumbers.length - 1].replace(/:/g, ""))

  return {
    lineNumber,
    errorMessage
  }
}

/**
 * Format and output an error coming from an evaluation
 * @param {AOSError} error
 */
export function outputError(error) {
  const lineNumberPlaceholder = " ".repeat(error.lineNumber.toString().length)

  console.log(
    chalk.bold(chalk.red("Error: " + error.errorMessage)) +
    "\n" +
    chalk.blue(`  ${lineNumberPlaceholder}  |\n  ${error.lineNumber}  |    `) +
    chalk.black(line.split("\n")[error.lineNumber - 1]) +
    "\n" +
    chalk.blue(`  ${lineNumberPlaceholder}  |\n`) +
    chalk.dim("This error occurred while aos was evaluating the submitted code.")
  )
}
