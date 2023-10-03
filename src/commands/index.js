import { register } from './register.js'

export function init(services) {
  return {
    register: args => register(args, services).toPromise()
  }
}