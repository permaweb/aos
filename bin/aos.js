#!/usr/bin/env node
import url from 'url'
import path from 'node:path'

const __dirname = url.fileURLToPath(new URL('.', import.meta.url))

import(path.resolve(__dirname + '../src/index.js'))