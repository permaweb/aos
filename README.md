# AOS REPL

> NOTE: This is very experimental, use for research and development purposes only.

The repl is a thin client to access and execute ao contracts on the permaweb.

## Getting Started

```sh
# create new project add arweave
yarn init -y
yarn add arweave

# Generate Wallet
node -e "require('arweave').init({}).wallets.generate().then(JSON.stringify).then(console.log.bind(console))" > wallet.json

# Boot up AOS
npx @permaweb/aos-cli@latest wallet.json
```

The wallet creates a personal process that allows you to use as a repl, you can send it commands and it will evaluate and return output.

## Examples

