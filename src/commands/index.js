import { register } from './register.js'
import { login } from './login.js'

export function init(services) {
  return {
    register: args => register(args, services),
    login: args => login(args, services)
  }
}