import { chalk } from '../utils/colors.js'
import { printWithBorder } from '../utils/print.js'
import { getPkg } from './get-pkg.js'

export function splash(options = {}) {
  const pkg = getPkg()

  const lines = [
    'Welcome to AOS: Your operating system for AO, the decentralized open access supercomputer.',
    'newline',
    `Client Version: ${pkg.version}. 2025`,
  ]

  if (options.walletAddress) {
    lines.push('newline')
    lines.push(('Wallet Address: ') + chalk.green(options.walletAddress))
  }

  if (Object.values(options).some(value => value)) {
    lines.push('newline')
    lines.push('divider')
  }

  lines.push(('Network: ') + chalk.green(options.legacy ? 'Legacynet' : 'Mainnet'))

  if (options.mainnetUrl) {
    lines.push(('Node: ') + chalk.green(options.mainnetUrl))
  }

  if (options.gatewayUrl) {
    lines.push(('Gateway: ') + chalk.green(options.gatewayUrl))
  }

  if (options.cuUrl) {
    lines.push(('CU: ') + chalk.green(options.cuUrl))
  }

  if (options.muUrl) {
    lines.push(('MU: ') + chalk.green(options.muUrl))
  }

  if (options.authority) {
    lines.push(('Authority: ') + chalk.green(options.authority))
  }
  
  if (options.scheduler) {
    lines.push(('Scheduler: ') + chalk.green(options.scheduler))
  }

  lines.push('newline')

  printWithBorder(lines, {
    title: 'AOS',
    borderColor: chalk.gray,
    titleColor: chalk.green,
  })
}