#!/bin/bash
set -e

# Step 1: Build the project
echo "Running: ao build"
ao build

# Step 2: Run tests
echo "Running: npm run test test/into.test.js"
npm run test test/into.test.js

# Step 3: Publish and capture output
echo "Running: ao publish ... (capturing module ID)"
publish_output=$(ao publish -w ./wallet.json ./process.wasm \
  -t Compute-Limit -v 9000000000000 \
  -t Memory-Limit -v 8589934592 \
  -t Name -v aos-test-2.0.4 \
  -t Module-Format -v wasm64-unknown-emscripten-draft_2024_02_15 \
  --bundler https://up.arweave.net)

# Optionally display the full publish output
echo "$publish_output"

# Step 4: Extract the 43-character alphanumeric module ID
# This pattern will match exactly 43 characters (letters, digits, underscore or hyphen if needed)
MODULE_ID=$(echo "$publish_output" | grep -oE "[A-Za-z0-9_-]{43}")
if [ -z "$MODULE_ID" ]; then
  echo "Error: Could not find a module ID in the publish output."
  exit 1
fi

echo "Extracted Module ID: $MODULE_ID"

# Step 5: Use the module ID in the final command
echo "Running: aos -w ./wallet.json --module=$MODULE_ID"
aos -w ./wallet.json --module=$MODULE_ID
