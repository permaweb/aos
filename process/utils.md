# Lua Utils Module Documentation

## Module Overview
The Lua Utils module provides a collection of utility functions for functional programming in Lua. It includes functions for array manipulation such as concatenation, mapping, reduction, filtering, and finding elements, as well as a property equality checker.

## Module Functions

### 1. `concat`
Concatenates two arrays.

- **Syntax:** `utils.concat(a)(b)`
- **Parameters:**
  - `a` (table): The first array.
  - `b` (table): The second array.
- **Returns:** A new array containing all elements from `a` followed by all elements from `b`.
- **Example:** `utils.concat({1, 2})({3, 4}) -- returns {1, 2, 3, 4}`

### 2. `map`
Applies a function to each element of an array.

- **Syntax:** `utils.map(fn)(t)`
- **Parameters:**
  - `fn` (function): A function to apply to each element.
  - `t` (table): The array to map over.
- **Returns:** A new array with each element being the result of applying `fn`.
- **Example:** `utils.map(function(x) return x * 2 end)({1, 2, 3}) -- returns {2, 4, 6}`

### 3. `reduce`
Reduces an array to a single value by iteratively applying a function.

- **Syntax:** `utils.reduce(fn)(initial)(t)`
- **Parameters:**
  - `fn` (function): A function to apply.
  - `initial`: Initial accumulator value.
  - `t` (table): The array to reduce.
- **Returns:** The final accumulated value.
- **Example:** `utils.reduce(function(acc, x) return acc + x end)(0)({1, 2, 3}) -- returns 6`

### 4. `filter`
Filters an array based on a predicate function.

- **Syntax:** `utils.filter(fn)(t)`
- **Parameters:**
  - `fn` (function): A predicate function to determine if an element should be included.
  - `t` (table): The array to filter.
- **Returns:** A new array containing only elements that satisfy `fn`.
- **Example:** `utils.filter(function(x) return x > 1 end)({1, 2, 3}) -- returns {2, 3}`

### 5. `find`
Finds the first element in an array that satisfies a predicate function.

- **Syntax:** `utils.find(fn)(t)`
- **Parameters:**
  - `fn` (function): A predicate function.
  - `t` (table): The array to search.
- **Returns:** The first element that satisfies `fn`, or `nil` if none do.
- **Example:** `utils.find(function(x) return x > 1 end)({1, 2, 3}) -- returns 2`

### 6. `propEq`
Checks if a specified property of an object equals a given value.

- **Syntax:** `utils.propEq(propName)(value)(object)`
- **Parameters:**
  - `propName` (string): The name of the property.
  - `value` (string): The value to compare against.
  - `object` (table): The object to check.
- **Returns:** `true` if `object[propName]` equals `value`, otherwise `false`.
- **Example:** `utils.propEq("name")("Lua")({name = "Lua"}) -- returns true`

## Version
- The module is currently at version 0.0.1.

## Notes
- This module is designed for functional programming style in Lua.
- It's important to ensure that inputs to these functions are of correct types as expected by each function.
- The module does not modify the original arrays but returns new arrays or values.

---

This documentation provides a basic overview and examples for each function in the Utils module. Users should adapt the examples to their specific use cases.