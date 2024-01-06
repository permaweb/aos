# Lua Library: Handlers (Version 0.0.3)

## Overview

The Handlers library provides a flexible way to manage and execute a series of handlers based on patterns. Each handler consists of a pattern function, a handle function, and a name. This library is suitable for scenarios where different actions need to be taken based on varying input criteria.

## Module Structure
- `handlers._version`: String representing the version of the Handlers library.
- `handlers.list`: Table storing the list of registered handlers.

## Functions

### `handlers.append(name, pattern, handle)`
Appends a new handler to the end of the handlers list.

#### Parameters
- `pattern` (function): Function that determines if the handler should be executed.
- `handle` (function): The handler function to execute.
- `name` (string): A unique name for the handler.

### `handlers.prepend(name, pattern, handle)`
Prepends a new handler to the beginning of the handlers list.

#### Parameters
- Same as `handlers.append`.

### `handlers.before(handleName)`
Returns an object that allows adding a new handler before a specified handler.

#### Parameters
- `handleName` (string): The name of the handler before which the new handler will be added.

#### Returns
- An object with an `add` method to insert the new handler.

### `handlers.after(handleName)`
Returns an object that allows adding a new handler after a specified handler.

#### Parameters
- `handleName` (string): The name of the handler after which the new handler will be added.

#### Returns
- An object with an `add` method to insert the new handler.

### `handlers.remove(name)`
Removes a handler from the handlers list by name.

#### Parameters
- `name` (string): The name of the handler to be removed.

### `handlers.evaluate(msg, env)`
Evaluates each handler against a given message and environment. Handlers are called in the order they appear in the handlers list.

#### Parameters
- `msg` (table): The message to be processed by the handlers.
- `env` (table): The environment in which the handlers are executed.

#### Returns
- `response` (varies): The response from the handler(s). Returns a default message if no handler matches.

## Usage Example
```lua
local handlers = require "handlers_module_path"

-- Define pattern and handle functions
local function myPattern(msg)
    -- Determine if the handler should be executed
end

local function myHandle(msg, env, response)
    -- Handler logic
end

-- Append a new handler
handlers.append("myHandler", myPattern, myHandle)

-- Evaluate a message
local response = handlers.evaluate({ key = "value" }, { envKey = "envValue" })
```

## Notes
- Handlers are executed in the order they appear in `handlers.list`.
- The pattern function should return `0` to skip the handler, `-1` to break after the handler is executed, or `1` to continue with the next handler.
- The `evaluate` function can concatenate responses from multiple handlers.
