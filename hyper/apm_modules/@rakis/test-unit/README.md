# Lua Test Module

This Lua test module provides a simple framework for defining and running unit tests. It allows you to create test suites, add test cases, and run the tests with a summary of the results.

## Features

- Create test suites
- Add test cases to the suite
- Run all test cases in the suite
- Print detailed results for each test case
- Summary of passed and failed tests

## Installation

Install with apm

```
.load-blueprint apm
APM.install('@rakis/test-unit')
```


## Usage

### Creating a Test Suite

Create a new test suite with a given name.

```lua
local Test = require("@rakis/test-unit")
local myTests = Test.new("My Test Suite")
```

### Adding Tests

Add test cases to the suite. Each test case is a function that contains assertions to check the expected outcomes.

```lua
myTests:add("Test Case 1", function()
    assert(1 + 1 == 2, "Math is broken!")
end)

myTests:add("Test Case 2", function()
    assert(type("hello") == "string", "Type check failed!")
end)
```

### Running Tests

Run all test cases in the suite and print the results.

```lua
local results = myTests:run()
print(results)
```

### Example

Here's a complete example demonstrating how to use the test module:

```lua
local Test = require("Test")

-- Create a new test suite
local myTests = Test.new("Example Test Suite")

-- Add test cases
myTests:add("Test Addition", function()
    assert(1 + 1 == 2, "Addition failed!")
end)

myTests:add("Test Type", function()
    assert(type("hello") == "string", "Type check failed!")
end)

-- Run the tests and print the results
local results = myTests:run()
print(results)
```

## License

This project is licensed under the MIT License.
