import chalk from 'chalk'

export function unmonitor(jwk, id, services) {
  return services.unmonitorProcess({ id, wallet: jwk })
    .map(x => (console.log("Result: ", chalk.blue(x)), x))

    .bimap(
      _ => chalk.red("Could not stop cron monitoring process."),
      _ => chalk.green("Successfully stopped cron monitoring process.")
    )
    .toPromise()
}