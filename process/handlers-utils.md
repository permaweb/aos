# README for Lua Module: _utils (v0.0.1)

## Overview
The `_utils` module is a lightweight Lua utility library designed to provide common functionalities for handling and processing messages within the AOS computer system. It offers a set of functions to check message attributes and send replies, simplifying the development of more complex scripts and modules. This document will guide you through the module's functionalities, installation, and usage.

### Version
0.0.1

## Installation

1. Ensure you have Lua installed on your AOS computer system.
2. Copy the `_utils.lua` file to your project directory or a designated Lua libraries directory.
3. Include the module in your Lua scripts using `local _utils = require('_utils')`.

## Features

### hasMatchingTag(name, value)
Checks if a given message has a tag that matches the specified name and value.

- **Parameters:**
  - `name` (string): The name of the tag to check.
  - `value` (string): The value of the tag to match.

- **Returns:** Function that takes a message object and returns `-1` if the tag matches, `0` otherwise.

### hasMatchingTagOf(name, values)
Checks if a given message has a tag that matches the specified name and one of the specified values.

- **Parameters:**
  - `name` (string): The name of the tag to check.
  - `values` (string): The values of which one should match.

- **Returns:** Function that takes a message object and returns `-1` if the tag matches, `0` otherwise.

### hasMatchingData(value)
Checks if the message data matches the specified value.

- **Parameters:**
  - `value` (string): The value to match against the message data.

- **Returns:** Function that takes a message object and returns `-1` if the data matches, `0` otherwise.

### reply(input)
Sends a reply to the sender of a message. The reply can be a simple string or a table with more complex data and tags.

- **Parameters:**
  - `input` (table or string): The content to send back. If a string, it sends it as data. If a table, it assumes a structure with `Tags`.

- **Returns:** Function that takes a message object and sends the specified reply.

### continue(fn)
Inverts the provided pattern matching function's result if it matches, so that it continues execution with the next matching handler.

- **Parameters:**
  - `fn` (function): Pattern matching function that returns `"skip"`, `false` or `0` if it does not match.

- **Returns:** Function that executes the pattern matching function and returns `1` (continue), so that the execution of handlers continues.

## Usage

1. **Import the module:**

   ```lua
   local _utils = require('_utils')
   ```

2. **Check for a specific tag in a message:**

   ```lua
   local isUrgent = _utils.hasMatchingTag('priority', 'urgent')
   if isUrgent(message) == -1 then
     print('This is an urgent message!')
   end
   ```

3. **Check for a specific tag with multiple possible values allowed:**
   
   ```lua
   local isNotUrgent = _utils.hasMatchingTagOf('priority', { 'trivial', 'unimportant' })
   if isNotUrgent(message) == -1 then
     print('This is not an urgent message!')
   end
   ```

4. **Check if the message data matches a value:**

   ```lua
   local isHello = _utils.hasMatchingData('Hello')
   if isHello(message) == -1 then
     print('Someone says Hello!')
   end
   ```

5. **Reply to a message:**

   ```lua
   local replyWithText = _utils.reply('Thank you for your message!')
   replyWithText(message)
   ```

   Or with complex data and tags:

   ```lua
   local replyWithTable = _utils.reply({Tags = {status = 'received'}})
   replyWithTable(message)
   ```

6. **Continue execution shortcut:**
   
   ```lua
   local isUrgent = _utils.continue(_utils.hasMatchingTag('priority', 'urgent'))
   if isUrgent(message) ~= 0 then
     print('This is an urgent message!')
   end
   if isUrgent(message) == -1 then return end
   print('This message will continue')
   ```

## Conventions and Requirements
- This module assumes that the message objects provided to functions follow a specific structure with `Tags` and `Data` attributes.
- Error handling is implemented using assertions. Ensure that your AOS environment appropriately handles or logs assertion failures.


## License

MIT