export function unmonitor(jwk, id, services) {
  return services.unmonitorProcess({ id, wallet: jwk })
    .map(x => (console.log(x), x))
    .map(x => "Successfully stopped monitoring process.")
    .toPromise()
}