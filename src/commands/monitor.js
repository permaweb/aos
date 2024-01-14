export function monitor(jwk, id, services) {
  return services.monitorProcess({ id, wallet: jwk })
    .map(x => (console.log(x), x))
    .map(x => "Successfully started monitoring process.")
    .toPromise()
}