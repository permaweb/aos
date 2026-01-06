import { chalk } from './colors.js'

function wrapLine(text, maxWidth) {
  const plainText = text.replace(/\x1b\[[0-9;]*m/g, '')

  if (plainText.length <= maxWidth) {
    return [text]
  }

  // For lines with ANSI codes, we need to be more careful
  // For now, just wrap plain text and accept we might lose some formatting
  const words = plainText.split(' ')
  const wrappedLines = []
  let currentLine = ''

  for (const word of words) {
    if ((currentLine + word).length <= maxWidth) {
      currentLine += (currentLine ? ' ' : '') + word
    } else {
      if (currentLine) {
        wrappedLines.push(currentLine)
      }
      currentLine = word
    }
  }

  if (currentLine) {
    wrappedLines.push(currentLine)
  }

  return wrappedLines.length > 0 ? wrappedLines : [plainText.substring(0, maxWidth)]
}

export function printWithBorder(lines, { title = '', titleColor = chalk.gray, borderColor = chalk.gray, width, truncate = false } = {}) {
  // Use terminal width if not specified
  const terminalWidth = process.stdout.columns || 175
  const defaultWidth = Math.min(175, Math.max(40, terminalWidth - 2))
  const boxWidth = width || defaultWidth
  const maxLineWidth = boxWidth - 4 // Account for "│  " and " │"

  const titleStr = title ? ` ${title} ` : ''
  const border = '─'.repeat(boxWidth - titleStr.length - 1)

  console.log('')
  console.log(borderColor(`╭─`) + titleColor(titleStr) + borderColor(border + `╮`))
  console.log(borderColor(`│${' '.repeat(boxWidth)}│`))

  for (const line of lines) {
    if (line === 'newline') {
      console.log(borderColor(`│${' '.repeat(boxWidth)}│`))
      continue
    }

    if (line === 'divider') {
      console.log(borderColor(`│  ${'─'.repeat(maxLineWidth)}  │`))
      console.log(borderColor(`│${' '.repeat(boxWidth)}│`))
      continue
    }

    if (truncate) {
      const plainText = line.replace(/\x1b\[[0-9;]*m/g, '')

      if (plainText.length > maxLineWidth) {
        // Truncate while preserving ANSI codes
        let visibleLength = 0
        let truncatedLine = ''
        let i = 0

        while (i < line.length && visibleLength < maxLineWidth - 3) {
          // Check for ANSI escape sequence
          if (line[i] === '\x1b' && line[i + 1] === '[') {
            // Find the end of the escape sequence
            let j = i + 2
            while (j < line.length && line[j] !== 'm') {
              j++
            }
            // Include the entire escape sequence
            truncatedLine += line.substring(i, j + 1)
            i = j + 1
          } else {
            truncatedLine += line[i]
            visibleLength++
            i++
          }
        }

        truncatedLine += '...'
        const padding = Math.max(0, maxLineWidth - (plainText.substring(0, visibleLength).length + 3))
        console.log(borderColor(`│  `) + truncatedLine + borderColor(' '.repeat(padding) + '  │'))
      } else {
        const padding = Math.max(0, maxLineWidth - plainText.length)
        console.log(borderColor(`│  `) + line + borderColor(' '.repeat(padding) + '  │'))
      }
    } else {
      const wrappedLines = wrapLine(line, maxLineWidth)

      for (const wrappedLine of wrappedLines) {
        const plainText = wrappedLine.replace(/\x1b\[[0-9;]*m/g, '')
        const padding = Math.max(0, maxLineWidth - plainText.length)
        console.log(borderColor(`│  `) + wrappedLine + borderColor(' '.repeat(padding) + '  │'))
      }
    }
  }

  console.log(borderColor(`╰${'─'.repeat(boxWidth)}╯`))
  console.log('');
}

export function printWithFormat(lineObj, opts) {
  if (lineObj) {
    if (Array.isArray(lineObj)) {
      for (const line of lineObj) {
        console.log(line)
      }
    }
    else console.log(lineObj)
  }
  if (!opts?.lineOnly) console.log('')
}
