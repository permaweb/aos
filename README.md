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

## About

AOS-CLI is a simple REPL that connects to a Personal AOS Process in the AO network. The AO network is a messaging passing process architecture. A Personal AOS Process is like a CPU on the Arweave Network. This repl will allow you to pass LUA expressions to your process, and those expressions get evaluated and return output to your screen.  

## Examples

When you boot up the OS, you can use https://lua.org to run expressions on your AOS Process.

First try "Hello AOS" - the return keyword sets the output variable that is passed to the output on the screen.

```lua
"Hello AOS"
```

You should get `Hello AOS`

> What is happening here? You input, is getting wrapped in an signed AO message and submitted to a `mu` or messenger unit, which then forwards it to a `su` or Sequencer Unit, then the REPL app, calls the `cu` compute unit to evaluate the AO Message with your Personal Process. This generates output to be returned for display.

Lets try another expression:

```lua
1 + 41
```

You should get `42` the answer to the universe :P

So, thats cool, you can send expressions to the AO network and get them evaluated and get a response.

You can also set variables:

```lua
a = "Hello AOS"
```

Then type `return a` and you should get `Hello AOS`, neat

You can also create functions:

```lua
sayHi = function (name) return "Hello " .. name end
return sayHi("Sam")
```

You should get `Hello Sam`

Woohoo!

We can also pass messages to other AOS Processes!

```lua
return send("9ps7pnC7hpdCYJGJujAg_QY-cyKbQ1GoaE5h-4elI9c", "Hi")
```

Or you can check your messages ( by creating a message check function)

```lua
list()
```

```
1: 
 target: 9iqfaJv0XtOzs4yZml0araVLhr_uXKB1_3Rq9U82PoE
 tags: 
  1: 
   name: Data-Protocol
   value: ao
  2: 
   name: ao-type
   value: message
  3: 
   name: Forwarded-For
   value: 9iqfaJv0XtOzs4yZml0araVLhr_uXKB1_3Rq9U82PoE
  4: 
   name: body
   value: Hi
  5: 
   name: Data-Protocol
   value: ao
  6: 
   name: ao-type
   value: message
  7: 
   name: SDK
   value: ao
 owner: z1pq2WzmaYnfDwvEFgUZBj48anUsxxN64ZjbWOsIn08
```


