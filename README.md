# AOS REPL

The repl is a thin client to access and execute ao contracts on the permaweb.

## Getting Started

```
yarn init -y
yarn add arweave
# Generate Wallet
node -e "require('arweave').init({}).wallets.generate().then(JSON.stringify).then(console.log.bind(console))" > wallet.json
# AOS
npx @permaweb/aos-cli wallet.json
```

The wallet creates a personal process that allows you to use as a repl, you can send it commands and it will evaluate and return output.

