import chalk from 'chalk'
import figlet from 'figlet'

export function splash() {
  console.log(figlet.textSync("aOS", {
    font: "Alpha",
    horizontalLayout: "full",
    verticalLayout: "full",
    width: 80,
    whitespaceBreak: true,
  }))
  console.log(chalk.green('Welcome to the ao Operating System.'))
}