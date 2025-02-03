import minimist from 'minimist'
const argv = minimist(process.argv.slice(2))

if (argv['dev']) {
  console.log('*** DEV ENVIRONMENT ***')

  process.env.GATEWAY_URL = 'https://arweave.net'
  process.env.CU_URL = 'https://ao-cu-0.ao-devnet.xyz'
  process.env.MU_URL = 'https://ao-mu-0.ao-devnet.xyz'
  process.env.SCHEDULER = 'gCpQfnG6nWLlKs8jYgV8oUfe38GYrPLv59AC7LCtCGg'
  
  console.log('GATEWAY_URL', process.env.GATEWAY_URL)
  console.log('CU', process.env.CU_URL)
  console.log('MU', process.env.MU_URL)
  console.log('SCHEDULER', process.env.SCHEDULER)
} else {
  process.env.GATEWAY_URL ||= 'https://arweave.net'
  process.env.CU_URL ||= 'https://cu.ao-testnet.xyz'
  process.env.MU_URL ||= 'https://mu.ao-testnet.xyz'
}

export function dev() {
  return process.env
}
