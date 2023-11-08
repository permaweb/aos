import { register } from './register.js'
import { evaluate } from './eval.js'

export function init(services) {
  // TODO: Validate Services
  return {
    register: jwk => register(jwk, services),
    evaluate: (data, contract, wallet) => evaluate(data, contract, wallet, services)
  }
}