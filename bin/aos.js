#!/usr/bin/env node
import url from 'url'

const __dirname = url.fileURLToPath(new URL('.', import.meta.url))

import(__dirname + '../src/index.js')