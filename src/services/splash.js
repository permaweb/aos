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
  console.log(chalk.green('Welcome to AOS: Your operating system for AO, the decentralized open access supercomputer.'))
  console.log(chalk.gray('Type ".load-blueprint chat" to join the community chat and ask questions!'))

}