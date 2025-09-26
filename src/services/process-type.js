export function resolveProcessTypeFromFlags(argv = {}) {
  if (argv.hyper) return 'hyper'
  if (argv.run) return 'aos'
  return null
}

export function shouldShowSplash(argv = {}) {
  return !Boolean(argv.run)
}

export function shouldSuppressVersionBanner(argv = {}) {
  return Boolean(argv.run)
}
