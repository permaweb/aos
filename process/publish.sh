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

# Define an output file
AOS_OUTPUT_FILE="aos_output.txt"
# Remove any existing output file
rm -f "$AOS_OUTPUT_FILE"

# Step 5: Use the module ID in the final command
echo "Running: aos -w ./wallet.json --module=$MODULE_ID"
AOS_PID=$!

# Wait a few seconds to let the output accumulate
sleep 10

# Kill the background process
kill "$AOS_PID" 2>/dev/null || true

# Read the output from the file
aos_output=$(cat "$AOS_OUTPUT_FILE")
echo "$aos_output"

# Step 6: Extract the AOS process from the captured output
# Example line: "Your AOS process: xpXa1ws-RK66TlXbI6OHybYNi7mZoxG3BZ1k5impnZc"
process_line=$(echo "$aos_output" | grep "Your AOS process:")
if [ -z "$process_line" ]; then
  echo "Error: Could not find the AOS process in the output."
  exit 1
fi

# Assuming the process ID is the fourth word in the line:
AOS_PROCESS=$(echo "$process_line" | awk '{print $4}')
echo "Extracted AOS Process: $AOS_PROCESS"
