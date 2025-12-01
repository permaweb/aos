/**
 * Terminal utility for preserving user input while printing output
 * Uses ANSI escape codes to save/restore cursor and clear lines
 */

let savedInput = ''
let savedCursorPosition = 0

/**
 * Save the current input line and cursor position
 * Should be called before printing any async output
 */
export function saveInput(rl) {
  if (!rl) return

  savedInput = rl.line || ''
  savedCursorPosition = rl.cursor || 0

  // Clear the current line (prompt + input)
  process.stdout.write('\r\x1b[K')
}

/**
 * Restore the saved input line and cursor position
 * Should be called after printing async output
 */
export function restoreInput(rl, showSeparator = false) {
  if (!rl) return

  // Add newline before prompt for spacing
  process.stdout.write('\n')

  // Rewrite the prompt and saved input
  process.stdout.write(rl.getPrompt() + savedInput)

  // Move cursor back to saved position
  if (savedCursorPosition < savedInput.length) {
    const charsToMoveBack = savedInput.length - savedCursorPosition
    process.stdout.write(`\x1b[${charsToMoveBack}D`)
  }
}

/**
 * Print output without disrupting user input
 * This saves the current input, prints the output, then restores input
 */
export function printWithoutDisruption(text, rl, showSeparator = true) {
  saveInput(rl)
  process.stdout.write(text + '\n')
  restoreInput(rl, showSeparator)
}
