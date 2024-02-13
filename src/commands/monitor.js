import chalk from 'chalk'

export function monitor(jwk, id, services) {
  return services.monitorProcess({ id, wallet: jwk })
    .map(x => (console.log("Request: ", chalk.blue(x)), x))
    .bimap(
      _ => chalk.red("Could not start cron monitoring process."),
      _ => chalk.green("Successfully started cron monitoring process.")
    )
    .toPromise()
}