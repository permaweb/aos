export const LUA_EXECUTION_DEVICE = 'lua@5.3'
export const GENESIS_WASM_EXECUTION_DEVICE = 'genesis-wasm'

const EXECUTION_DEVICES = [LUA_EXECUTION_DEVICE, GENESIS_WASM_EXECUTION_DEVICE]

export function resolveProcessTypeFromFlags(argv = {}) {
  if (!argv.legacy) return 'mainnet'
  if (argv.hyper) return 'hyper'
  if (argv.run) return 'aos'
  return null
}

export function resolveExecutionDeviceFromFlags(argv = {}) {
  const executionDevice =
    argv['execution-device'] ??
    (argv.sqlite ? GENESIS_WASM_EXECUTION_DEVICE : LUA_EXECUTION_DEVICE)

  if (!EXECUTION_DEVICES.includes(executionDevice)) {
    throw new Error(
      `Invalid --execution-device "${executionDevice}". Expected "lua@5.3" or "genesis-wasm".`
    )
  }

  if (argv.sqlite && executionDevice !== GENESIS_WASM_EXECUTION_DEVICE) {
    throw new Error('The --sqlite flag requires --execution-device genesis-wasm.')
  }

  return executionDevice
}

export function defaultModuleForExecutionDevice(pkg, executionDevice) {
  return executionDevice === LUA_EXECUTION_DEVICE ? pkg.hyper.module : pkg.aos.module
}

export function shouldShowSplash(argv = {}) {
  return !Boolean(argv.run)
}

export function shouldSuppressVersionBanner(argv = {}) {
  return Boolean(argv.run)
}
