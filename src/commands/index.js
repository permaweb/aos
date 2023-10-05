import { register } from './register.js'
import { login } from './login.js'
import { echo } from './echo.js'
import { evaluate } from './eval.js'

export function init(services) {
  return {
    register: jwk => register(jwk, services),
    login: jwk => login(jwk, services),
    echo: (data, contract, wallet) => echo(data, contract, wallet, services),
    evaluate: (data, contract, wallet) => evaluate(data, contract, wallet, services)
  }
}