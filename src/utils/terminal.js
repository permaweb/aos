import readline from 'readline'

/**
 * Terminal utility for managing a fixed prompt line
 * This keeps the prompt at the bottom of the terminal while output scrolls above
 */

export class FixedPromptTerminal {
  constructor() {
    this.promptLine = ''
    this.outputBuffer = []
  }

  /**
   * Set up the terminal with a scrolling region
   */
  setup() {
    const rows = process.stdout.rows || 24
    // Set scrolling region (leave last 2 lines for prompt)
    process.stdout.write(`\x1b[1;${rows - 2}r`)
    // Move cursor to bottom
    process.stdout.write(`\x1b[${rows - 1};1H`)
  }

  /**
   * Write output to the scrolling region
   */
  writeOutput(text) {
    const rows = process.stdout.rows || 24
    // Save cursor position
    process.stdout.write('\x1b7')
    // Move to scrolling region
    process.stdout.write(`\x1b[${rows - 3};1H`)
    // Write the output
    process.stdout.write(text + '\n')
    // Restore cursor position
    process.stdout.write('\x1b8')
  }

  /**
   * Update the prompt line at the bottom
   */
  updatePrompt(promptText) {
    const rows = process.stdout.rows || 24
    // Move to prompt line
    process.stdout.write(`\x1b[${rows - 1};1H`)
    // Clear the line
    process.stdout.write('\x1b[2K')
    // Write prompt
    process.stdout.write(promptText)
    this.promptLine = promptText
  }

  /**
   * Cleanup terminal settings
   */
  cleanup() {
    // Reset scrolling region
    process.stdout.write('\x1b[r')
    // Clear screen
    process.stdout.write('\x1b[2J')
    // Move cursor to top
    process.stdout.write('\x1b[H')
  }
}
