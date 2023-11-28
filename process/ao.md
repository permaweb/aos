# Lua Library: AO (Version 0.0.2)

## Overview
The AO library is designed to facilitate communication and process creation within a specific system, identified by its unique ID. This version (0.0.2) includes functionalities for sending structured messages and spawning new processes with custom tags.

## Module Structure
- `ao._version`: String representing the version of the AO library.
- `ao.id`: String representing the unique identifier for the AO system.

## Functions

### `ao.send(input, target)`

creates a message box and returns a message object to be added to the outbox

#### Parameters
- `input` (table): A table containing key-value pairs representing the data to be sent in the message.
- `target` (string): A process id specifying the target recipient of the message.

#### Returns
- `message` (table): A table structured as a message, containing the target and tags with the provided input and system information. Note, you want to return the this message in the messages array.

#### Usage

```lua
local message = ao.send({ ["function"] = "transfer", target = "WALLET2", qty = 1 }, "TOKEN_PROCESS")
return {
  output = "transfer 1 token to WALLET2",
  messages = { message }
}
```

### `ao.spawn(data, tags)`
Creates a new process within the AO system, attaching custom tags to it.

#### Parameters
- `data`: The data or content for the new process.
- `tags` (table): A table of key-value pairs representing tags to be associated with the process.

#### Returns
- `spawn` (table): A table representing the spawned process, including data and tags.

#### Usage
```lua
local process = ao.spawn("process_data", { tag1 = "value1", tag2 = "value2" })
```

## Notes
- The `ao.send` and `ao.spawn` functions perform assertions to ensure that inputs are of the correct type. Misuse or incorrect types will result in an error.
- The library makes use of the `ao.id` to tag messages and processes, ensuring they are traceable to the originating system.

## Example
```lua
local ao = require "ao_library_path"

ao.id = "system123"

-- Sending a message
local message = ao.send({ content = "Hello, World!" }, "target_system")
-- message now contains structured data to be sent

-- Spawning a process
local process = ao.spawn("Data for new process", { priority = "high" })
-- process now contains structured data for a new process
```
