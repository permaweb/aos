# Lua Library: AO (Version 0.0.3)

## Overview
The AO library, version 0.0.3, is designed for managing messages and process spawns within a network system. This library allows for the creation and handling of messages and spawns, maintaining them in an outbox for further processing.

## Module Structure
- `ao._version`: String representing the version of the AO library.
- `ao.id`: String representing the unique identifier for the AO system.
- `ao.outbox`: Table containing two sub-tables, `messages` and `spawns`, to store outgoing messages and spawn requests.

## Functions

### `ao.clearOutbox()`
Clears the outbox by resetting the `messages` and `spawns` tables.

#### Usage
```lua
ao.clearOutbox()
```

### `ao.send(input, target)`
Sends a message to a specified target, adding the message to the outbox.

#### Parameters
- `input` (table): A table containing key-value pairs to be included in the message.
- `target` (string): A string specifying the target recipient of the message.

#### Returns
- `message` (table): A table representing the structured message added to the outbox.

#### Usage
```lua
local message = ao.send({ key1 = "value1", key2 = "value2" }, "target_system")
```

### `ao.spawn(module, tags, data)`
Creates a spawn request with the given module source, tags and optionally data, adding the spawn to the outbox.

#### Parameters
- `module` (string):  module source associated with the spawn request.
- `tags` (table): A table of key-value pairs representing tags for the spawn.
- `[data]` (binary or string): Optional data for creating Atomic Assets

#### Returns
- `spawn` (table): A table representing the spawn request added to the outbox.

#### Usage
```lua
local spawnRequest = ao.spawn("MODULE", { name = "Foo Coin", ticker = "FOO" })
```

## Usage Example
```lua
local ao = require "ao_library_path"
ao.id = "system123"

-- Sending a message
local message = ao.send({ content = "Hello, World!" }, "target_system")
-- The message is now stored in ao.outbox.messages

-- Creating a spawn request
local spawn = ao.spawn("Data for new process", { priority = "high" })
-- The spawn request is now stored in ao.outbox.spawns

-- Clearing the outbox
ao.clearOutbox()
-- ao.outbox.messages and ao.outbox.spawns are now empty
```

## Notes
- The `ao.send` and `ao.spawn` functions automatically add the created message and spawn request to the `ao.outbox` for later processing.
- The `ao.clearOutbox` function is useful for resetting the outbox after the messages and spawns have been processed or dispatched.

---

This documentation provides a comprehensive overview of the AO library's functionality, enabling developers to effectively utilize its features for managing messages and spawns within a networked environment.