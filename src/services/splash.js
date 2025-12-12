import { chalk } from '../utils/colors.js'
import { printWithBorder } from '../utils/print.js'
import { getPkg } from './get-pkg.js'

export function splash(options = {}) {
  const pkg = getPkg()

  const lines = [
    chalk.white('Welcome to AOS: Your operating system for AO, the decentralized open access supercomputer.'),
    'newline',
    chalk.white(`Client Version: ${pkg.version}. 2025`),
  ]

  if (options.walletAddress) {
    lines.push('newline')
    lines.push(chalk.white('Wallet Address: ') + chalk.green(options.walletAddress))
  }

  if (Object.values(options).some(value => value)) {
    lines.push('newline')
    lines.push('divider')
  }

  lines.push(chalk.white('Network: ') + chalk.green(options.legacy ? 'Legacynet' : 'Mainnet'))

  if (options.mainnetUrl) {
    lines.push(chalk.white('Node: ') + chalk.green(options.mainnetUrl))
  }

  if (options.gatewayUrl) {
    lines.push(chalk.white('Gateway: ') + chalk.green(options.gatewayUrl))
  }

  if (options.cuUrl) {
    lines.push(chalk.white('CU: ') + chalk.green(options.cuUrl))
  }

  if (options.muUrl) {
    lines.push(chalk.white('MU: ') + chalk.green(options.muUrl))
  }

  if (options.authority) {
    lines.push(chalk.white('Authority: ') + chalk.green(options.authority))
  }
  
  if (options.scheduler) {
    lines.push(chalk.white('Scheduler: ') + chalk.green(options.scheduler))
  }

  lines.push('newline')

  printWithBorder(lines, {
    title: 'AOS',
    borderColor: chalk.gray,
    titleColor: chalk.green,
  })
}