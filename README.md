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
return "Hello AOS"
```

You should get `Hello AOS`

> What is happening here? You input, is getting wrapped in an signed AO message and submitted to a `mu` or messenger unit, which then forwards it to a `su` or Sequencer Unit, then the REPL app, calls the `cu` compute unit to evaluate the AO Message with your Personal Process. This generates output to be returned for display.

Lets try another expression:

```lua
return 1 + 41
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
return sendMsg("9ps7pnC7hpdCYJGJujAg_QY-cyKbQ1GoaE5h-4elI9c", "Hi Tom!")
```

Or you can check your messages

```lua
return checkMsgs()
```

`[{"from":"9ps7pnC7hpdCYJGJujAg_QY-cyKbQ1GoaE5h-4elI9c","body":"Hi"}]`

Now if you don't like that formater, you can access the inbox table and format it a different way.

> NOTE: you can use `.editor` to write you code in multiple lines, then use `ctrl-d` to send.

```lua
.editor
// Entering editor mode (Ctrl+D to finish, Ctrl+C to cancel)
printMsgs = function() 
  local o = ""
  for i,v in _global.ipairs(inbox) do
    o = o .. v.body .. '\n'
  end
  return o
end
```

```lua
return printMsgs()
```


You can also tap into the `receiveMsg` by setting an expression to handle a reply.

```lua
return setReceiveFn("if state.inbox[#state.inbox].from ~= SmartWeave.contract.id then return { target = state.inbox[#state.inbox].from, message = { ['function'] = 'receiveMsg', body = 'Thank you for sending message', from = SmartWeave.contract.id }} end");
```


