import minimist from 'minimist'
const argv = minimist(process.argv.slice(2))

if (argv['dev']) {
  console.log('*** DEV ENVIRONMENT ***')

  process.env.GATEWAY_URL = 'https://arweave.net'
  process.env.CU_URL = 'https://ao-cu-router-1.onrender.com'
  process.env.MU_URL = 'https://ao-mu-router-1.onrender.com'
  //process.env.SCHEDULER = 'TZ7o7SIZ06ZEJ14lXwVtng1EtSx60QkPy-kh-kdAXog'

  console.log('GATEWAY_URL', process.env.GATEWAY_URL)
  console.log('CU', process.env.CU_URL)
  console.log('MU', process.env.MU_URL)
  console.log('SCHEDULER', process.env.SCHEDULER)
} else {
  process.env.GATEWAY_URL ||= 'https://arweave.net'
  process.env.CU_URL      ||= 'https://cu.ao-testnet.xyz'
  process.env.MU_URL      ||= 'https://mu.ao-testnet.xyz'
}

export function dev() {
  return process.env
}
