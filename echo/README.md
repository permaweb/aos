# Echo AO Process

This process is an echo process, when it receives a message it replys with a result.

## Build

`ao build`

## Publish Source

`ao publish -w [wallet] process.wasm`

## Spawn Process

> Change the source to use the ao wasm source from the publish function.

`node spawn.js`