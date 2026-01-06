import minimist from 'minimist'
import { config } from '../config.js'
const argv = minimist(process.argv.slice(2))

if (argv['dev']) {
  console.log('*** DEV ENVIRONMENT ***')

  process.env.GATEWAY_URL = config.urls.GATEWAY
  process.env.CU_URL = config.urls.CU_DEV
  process.env.MU_URL = config.urls.MU_DEV
  process.env.SCHEDULER = 'gCpQfnG6nWLlKs8jYgV8oUfe38GYrPLv59AC7LCtCGg'

  console.log('GATEWAY_URL', process.env.GATEWAY_URL)
  console.log('CU', process.env.CU_URL)
  console.log('MU', process.env.MU_URL)
  console.log('SCHEDULER', process.env.SCHEDULER)
} else {
  process.env.GATEWAY_URL ||= config.urls.GATEWAY
  process.env.CU_URL ||= config.urls.CU_TESTNET
  process.env.MU_URL ||= config.urls.MU_TESTNET
}

export function dev() {
  return process.env
}
