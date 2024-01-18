# aos

## Requirements

* [NodeJS](https://nodejs.org) version 20+

## Getting Started

```sh
npm i -g https://get_ao.g8way.io && aos
```

> NOTE: after the first time you run `aos` it installs it to your local machine, so the next time you want to run `aos`, just type `aos` + [enter]

## About

aos is a command-line app that connects to your `aos` Process on the ao Permaweb Computer Grid. The ao Computer Grid, is like the internet, but for compute. Each Process on the Grid can receive messages and send messages. This cli will allow you to pass LUA expressions to your Process, and those expressions get evaluated and return output to your system.  

## Examples

When you boot up the aos, you can use https://lua.org to run expressions on your `aos` Process.

First try "Hello aos" - the return keyword sets the output variable that is passed to the output on the screen.

```lua
"Hello aos"
```

You should get `Hello aos`

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
a = "Hello aos"
```

Then type `return a` and you should get `Hello aos`, neat

You can also create functions:

```lua
sayHi = function (name) return "Hello " .. name end
return sayHi("Sam")
```

You should get `Hello Sam`

Woohoo! 🚀

We can also pass messages to other `aos` Processes!

```lua
Send({ Target = "Nhm2K5O87Gf6wZCK9u8gWUOqpc6IGgj7QSksGryt8-g", Data = "ping" })
```

Check the number of items in your `Inbox`:

```
#Inbox
```

Check the body Tag of the last message in your inbox:

```
Inbox[#Inbox].Data
```

> Should be `pong` 

Or you can check your messages by typing `inbox`

```lua
Inbox
```

### Prompt

Want to customize your `Prompt`, all you have to do is to overwrite the `Prompt` function

```lua
function Prompt() return "🐶> " end
```

Nice, you should see your new prompt.


### handlers

With `aos` you can add handlers to handle incoming messages, in this example, we will create a handler for "ping" - "pong".

In the `aos`, type `.editor`

```lua
Handlers.add(
  "pingpong",
  Handlers.utils.hasMatchingData("ping"),
  Handlers.utils.reply("pong")
)
```

Then type `.done`

>  This will submit a handler to listen for messages that have a `body` tag with a value of `ping` then send back a message `pong`.

Once added you can ping yourself!

```lua
Send({Target = ao.id, Data = "ping" })
```

And check your inbox, you should have gotten a `pong` message.

this utility function finds the `body` Tag of the last message in the inbox and returns the `value`

```lua
Inbox[#Inbox].Data
```

You should see `pong` 

:tada:

For more information about `Handlers` check out the handlers [docs](process/handlers.md) 

## Chatroom 

Let's create a chatroom Process, with this chatroom, we want processes to be able to `Register` and `Broadcast` Actions. In order to create this Process, we will use an external editor to create a `chatroom.lua` file. Then use the `.load` feature to update our Process.

chatroom.lua

```lua
Weavers = Weavers = {}

Handlers.add(
  "register", 
  Handlers.utils.hasMatchingTag("Action", "Register"),
  function (msg) 
    table.insert(Weavers, msg.From)
    -- reply letting process know they are registered
    Handlers.utils.reply("registered")(msg)
  end
)


Handlers.add(
  "broadcast",
  Handlers.utils.hasMatchingTag("Action", "Broadcast"),
  function (msg)
    for index, recipient in ipairs(Weavers) do
      ao.send({Target = recipient, Data = msg.Data})
    end
    Handlers.utils.reply("Broadcasted.")(msg)
  end

)
```

Now, that we have our handlers, let's load them into our process:

```lua
.load chatroom.lua
```

Sweet! You can test on `aos`

```lua
Send({Target = ao.id, Tags = { Action = "Register" }})
```

```lua
Weavers[#Weavers]
```

You should see your address

Now, lets broadcast!

```lua
Send({Target = ao.id, Tags = { Action = "Broadcast" }, Data = "gm"})
```

lets dump the inbox to see all the data.

```lua
dump(Inbox)
```

Ok, now get some friends to send some messages to your process.

Once we have confirmed it is working, maybe we do not want to broadcast a message to ourself? 

Lets edit the `chatroom.lua` file in the `Broadcast` function to skip the sender.

```lua
Handlers.add(
  "broadcast",
  handlers.utils.hasMatchingTag("Action", "Broadcast"),
  function (msg)
    for index, recipient in ipairs(Weavers) do
      -- skip message sender
      if recipient ~= msg.From then
       ao.send({Target = recipient, Data = msg.Data})
      end
    end
    Handlers.utils.reply("Broadcasted.")(msg)
  end

)
```

## Token

Let's also make our Process a token, create a `token.lua` file and add this lua expression:

```lua
Balances = Balances or {}
Name = Name or "[your token name]"
Ticker = Ticker or "[symbol]"
Logo = Logo or "Your Logo TXID"
Denomination = Denomination or 6

--[[
  Info
]] --
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
  ao.send({ Target = msg.From, Tags = { 
    Name = Name, 
    Ticker = Ticker, 
    Logo = Logo, 
    Denomination = tostring(Denomination) 
  }})
end)

--[[
  Balance
]] --
Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
  local bal = '0'

  -- If not Target is provided, then return the Senders balance
  if (msg.Tags.Target and Balances[msg.Tags.Target]) then
    bal = tostring(Balances[msg.Tags.Target])
  elseif Balances[msg.From] then
    bal = tostring(Balances[msg.From])
  end

  ao.send({
    Target = msg.From,
    Tags = { Target = msg.From, Balance = bal, Ticker = Ticker, Data = json.encode(tonumber(bal)) }
  })
end)

--[[
  Balances
]] --
Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'),
             function(msg) ao.send({ Target = msg.From, Data = json.encode(Balances) }) end)

--[[
  Transfer
]] --
Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg)
  assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')
  assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

  if not Balances[msg.From] then Balances[msg.From] = 0 end

  if not Balances[msg.Tags.Recipient] then Balances[msg.Tags.Recipient] = 0 end

  local qty = tonumber(msg.Tags.Quantity)
  assert(type(qty) == 'number', 'qty must be number')

  if Balances[msg.From] >= qty then
    Balances[msg.From] = Balances[msg.From] - qty
    Balances[msg.Tags.Recipient] = Balances[msg.Tags.Recipient] + qty

    --[[
      Only send the notifications to the Sender and Recipient
      if the Cast tag is not set on the Transfer message
    ]] --
    if not msg.Tags.Cast then
      -- Send Debit-Notice to the Sender
      ao.send({
        Target = msg.From,
        Tags = { Action = 'Debit-Notice', Recipient = msg.Tags.Recipient, Quantity = tostring(qty) }
      })
      -- Send Credit-Notice to the Recipient
      ao.send({
        Target = msg.Tags.Recipient,
        Tags = { Action = 'Credit-Notice', Sender = msg.From, Quantity = tostring(qty) }
      })
    end
  else
    ao.send({
      Target = msg.Tags.From,
      Tags = { Action = 'Transfer-Error', ['Message-Id'] = msg.Id, Error = 'Insufficient Balance!' }
    })
  end
end)

--[[
 Mint
]] --
Handlers.add('mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), function(msg, env)
  assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

  if msg.From == env.Process.Id then
    -- Add tokens to the token pool, according to Quantity
    local qty = tonumber(msg.Tags.Quantity)
    Balances[env.Process.Id] = Balances[env.Process.Id] + qty
  else
    ao.send({
      Target = msg.Tags.From,
      Tags = {
        Action = 'Mint-Error',
        ['Message-Id'] = msg.Id,
        Error = 'Only the Process Owner can mint new ' .. Ticker .. ' tokens!'
      }
    })
  end
end)
```

```lua
.load token.lua
```

BAM! We just converted our Process to a Token on aos... 🤯

## Summary

Hopefully, you are able to see the power of aos in this demo, access to compute from anywhere in the world. 

Welcome to the `ao` Permaweb Computer Grid! We are just getting started! 🐰

## Reference

### Managing Multiple processes

When you run `aos` command with no arguments it will default the process you are connected to as `default`, if you want to run or access a different process that you manage, you simply add a name.

```
aos chatroom
```

These names are unique to your wallet.

### Loading lua source files

Using the command-line you can load one or more lua source files into your process

```
aos --load token.lua --load dao.lua
```

### .load lua source in aos

You can also load lua sources files in aos

```
aos> .load luafile.lua
```


