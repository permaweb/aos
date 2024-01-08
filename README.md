# aOS

> NOTE: This project experimental, not recommended for production use.

## Requirements

* [NodeJS](https://nodejs.org) version 20+

## Getting Started

```sh
npm i -g https://sh_ao.g8way.io && aos
```

> NOTE: after the first time you run `aos` it installs it to your local machine, so the next time you want to run `aos`, just type `aos` + [enter]

## About

aos is a command-line app that connects to your `aOS` Process on the ao Permaweb Computer Grid. The ao Computer Grid, is like the internet, but for compute. Each Process on the Grid can receive messages and send messages. This cli will allow you to pass LUA expressions to your Process, and those expressions get evaluated and return output to your system.  

## Examples

When you boot up the aOS, you can use https://lua.org to run expressions on your `aOS` Process.

First try "Hello aOS" - the return keyword sets the output variable that is passed to the output on the screen.

```lua
"Hello aOS"
```

You should get `Hello aOS`

> What is happening here? Your input, is getting wrapped in an signed `ao` message and submitted to a messenger unit, which then forwards it to a Scheduler Unit, then the app, calls a compute unit to evaluate the `ao` Message with your Process. This generates output to be returned for display.

![Workflow](aos-workflow.png)

Lets try another expression:

```lua
1 + 41
```

You should get `42` the answer to the universe 😛

So, thats cool, you can send expressions to the `ao` Permaweb Computer to your Process, and you get returned a response.

You `aOS` process also has memory, so you can set `variables`

```lua
a = "Hello aOS"
```

Then type `return a` and you should get `Hello aOS`, neat

You can also create functions:

```lua
sayHi = function (name) return "Hello " .. name end
return sayHi("Sam")
```

You should get `Hello Sam`

Woohoo! 🚀

We can also pass messages to other `aOS` Processes!

```lua
send({ Target = "ohc9mIsNs3CFmMu7luiazRDLCFpiFJCfGVomJNMNHdU", Tags = { body = "ping" } })
```

Check the number of items in your `inbox`:

```
#inbox
```

Check the body Tag of the last message in your inbox:

```
inbox[#inbox].Data
```

> Should be `pong` 

Or you can check your messages ( by a `list()`)

```lua
list()
```

```
1: 
 Target: ohc9mIsNs3CFmMu7luiazRDLCFpiFJCfGVomJNMNHdU
 ...
 Tags: 
  From-Process: ohc9mIsNs3CFmMu7luiazRDLCFpiFJCfGVomJNMNHdU
  Type: Message
  body: pong
  Variant: ao.TN.1
  Data-Protocol: ao
```

### handlers

With `aOS` you can add handlers to handle incoming messages, in this example, we will create a handler for "ping" - "pong".

In the `aOS`, type `.editor`

```lua
handlers.add(
  "pingpong",
  handlers.utils.hasMatchingData("ping"),
  handlers.utils.reply("pong")
)
```

Then type `.done`

>  This will submit a handler to listen for messages that have a `body` tag with a value of `ping` then send back a message `pong`.

Once added you can ping yourself!

```lua
send({Target = ao.id, Data = "ping" })
```

And check your inbox, you should have gotten a `pong` message.

this utility function finds the `body` Tag of the last message in the inbox and returns the `value`

```lua
inbox[#inbox].Data
```

You should see `pong` 

:tada:

For more information about `handlers` check out the handlers [docs](process/handlers.md) 

## Summary

Hopefully, you are able to see the power of aOS in this demo, access to compute from anywhere in the world. 

Welcome to the `ao` Permaweb Computer Grid! We are just getting started! 🐰

## notes

* intro
* console
* messages
* handlers
* chatroom
* token