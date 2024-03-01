import { ProxyAgent } from 'undici';

if (process.env.HTTPS_PROXY) {
  const proxyAgent = new ProxyAgent(process.env.HTTPS_PROXY);
  const nodeFetch = globalThis.fetch
  globalThis.fetch = function (url, options) {
    return nodeFetch(url, { ...options, dispatcher: proxyAgent })
  }
}