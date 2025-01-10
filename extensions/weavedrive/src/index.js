const Arweave = require('arweave')

const KB = 1024
const MB = KB * 1024
const CACHE_SZ = 32 * KB
const CHUNK_SZ = 128 * MB
const NOTIFY_SZ = 512 * MB

module.exports = function weaveDrive (mod, FS) {
  return {
    reset (fd) {
      // console.log("WeaveDrive: Resetting fd: ", fd)
      FS.streams[fd].node.position = 0
      FS.streams[fd].node.cache = new Uint8Array(0)
    },

    joinUrl ({ url, path }) {
      if (!path) return url
      if (path.startsWith('/')) return this.joinUrl({ url, path: path.slice(1) })

      url = new URL(url)
      url.pathname += path
      return url.toString()
    },

    async customFetch (path, options) {
      /**
       * mod.ARWEAVE may be a comma-delimited list of urls.
       * So we parse it into an array that we sequentially consume
       * using fetch, and return the first successful response.
       *
       * The first url is considered "primary". So if all urls fail
       * to produce a successful response, then we return the primary's
       * error response
       */
      const urlList = mod.ARWEAVE.includes(',')
        ? mod.ARWEAVE.split(',').map(url => url.trim())
        : [mod.ARWEAVE]

      let p
      for (const url of urlList) {
        const res = fetch(this.joinUrl({ url, path }), options)
        if (await res.then((r) => r.ok).catch(() => false)) return res
        if (!p) p = res
      }

      /**
       * None succeeded so fallback to the primary and accept
       * whatever it returned
       */
      return p
    },

    async create (id) {
      const properties = { isDevice: false, contents: null }

      if (!await this.checkAdmissible(id)) {
        // console.log("WeaveDrive: Arweave ID is not admissable! ", id)
        return 'HALT'
      }

      // Create the file in the emscripten FS

      // This check/mkdir was added for AOP 6 Boot loader because create is
      // called first because were only loading Data, we needed to create
      // the directory. See: https://github.com/permaweb/aos/issues/342
      if (!FS.analyzePath('/data/').exists) {
        FS.mkdir('/data/')
      }

      const node = FS.createFile('/', 'data/' + id, properties, true, false)

      // Set initial parameters
      const response = await this.customFetch(`/${id}`, { method: 'HEAD', headers: { 'Accept-Encoding': 'identity' } })
      if (!response.ok) {
        return 'HALT'
      }
      const bytesLength = response.headers.get('Content-Length')
      node.total_size = Number(bytesLength)
      node.cache = new Uint8Array(0)
      node.position = 0

      // Add a function that defers querying the file size until it is asked the first time.
      Object.defineProperties(node, { usedBytes: { get: function () { return bytesLength } } })

      // Now we have created the file in the emscripten FS, we can open it as a stream
      const stream = FS.open('/data/' + id, 'r')

      // console.log("JS: Created file: ", id, " fd: ", stream.fd);
      return stream
    },
    async createBlockHeader (id) {
      const customFetch = this.customFetch
      // todo: add a bunch of retries
      async function retry (x) {
        return new Promise(resolve => {
          setTimeout(function () {
            resolve(customFetch(`/block/height/${id}`))
          }, x * 10000)
        })
      }
      const result = await this.customFetch(`/block/height/${id}`)
        .then(res => !res.ok ? retry(1) : res)
        .then(res => !res.ok ? retry(2) : res)
        .then(res => !res.ok ? retry(3) : res)
        .then(res => !res.ok ? retry(4) : res)
        .then(res => res.text())

      FS.createDataFile('/', 'block/' + id, Buffer.from(result, 'utf-8'), true, false)

      const stream = FS.open('/block/' + id, 'r')
      return stream
    },
    async createTxHeader (id) {
      const customFetch = this.customFetch
      async function toAddress (owner) {
        return Arweave.utils.bufferTob64Url(
          await Arweave.crypto.hash(Arweave.utils.b64UrlToBuffer(owner))
        )
      }
      async function retry (x) {
        return new Promise(resolve => {
          setTimeout(function () {
            resolve(customFetch(`/tx/${id}`))
          }, x * 10000)
        })
      }
      // todo: add a bunch of retries
      const result = await this.customFetch(`/tx/${id}`)
        .then(res => !res.ok ? retry(1) : res)
        .then(res => !res.ok ? retry(2) : res)
        .then(res => !res.ok ? retry(3) : res)
        .then(res => !res.ok ? retry(4) : res)
        .then(res => res.json())
        .then(async entry => ({ ...entry, ownerAddress: await toAddress(entry.owner) }))
        // .then(x => (console.error(x), x))
        .then(x => JSON.stringify(x))

      FS.createDataFile('/', 'tx/' + id, Buffer.from(result, 'utf-8'), true, false)
      const stream = FS.open('/tx/' + id, 'r')
      return stream
    },
    async open (filename) {
      const pathCategory = filename.split('/')[1]
      const id = filename.split('/')[2]
      if (pathCategory === 'tx') {
        FS.createPath('/', 'tx', true, false)
        if (FS.analyzePath(filename).exists) {
          const stream = FS.open(filename, 'r')
          if (stream.fd) return stream.fd
          return 0
        } else {
          const stream = await this.createTxHeader(id)
          return stream.fd
        }
      }
      if (pathCategory === 'block') {
        FS.createPath('/', 'block', true, false)
        if (FS.analyzePath(filename).exists) {
          const stream = FS.open(filename, 'r')
          if (stream.fd) return stream.fd
          return 0
        } else {
          const stream = await this.createBlockHeader(id)
          return stream.fd
        }
      }
      if (pathCategory === 'data') {
        if (FS.analyzePath(filename).exists) {
          const stream = FS.open(filename, 'r')
          if (stream.fd) return stream.fd
          return 0
        } else {
          const stream = await this.create(id)
          if (typeof stream === 'string') {
            return 'HALT: FILE NOT FOUND'
          }
          return stream.fd
        }
      } else if (pathCategory === 'headers') {
        console.log('Header access not implemented yet.')
        return 0
      } else {
        console.log('JS: Invalid path category: ', pathCategory)
        return 0
      }
    },
    async read (fd, rawDstPtr, rawLength) {
      // Note: The length and dstPtr are 53 bit integers in JS, so this _should_ be ok into a large memspace.
      let toRead = Number(rawLength)
      let dstPtr = Number(rawDstPtr)

      let stream = 0
      for (let i = 0; i < FS.streams.length; i++) {
        if (FS.streams[i].fd === fd) {
          stream = FS.streams[i]
        }
      }
      // read block headers
      if (stream.path.includes('/block')) {
        mod.HEAP8.set(stream.node.contents.subarray(0, toRead), dstPtr)
        return toRead
      }
      // read tx headers
      if (stream.path.includes('/tx')) {
        mod.HEAP8.set(stream.node.contents.subarray(0, toRead), dstPtr)
        return toRead
      }
      // Satisfy what we can with the cache first
      let bytesRead = this.readFromCache(stream, dstPtr, toRead)
      stream.position += bytesRead
      stream.lastReadPosition = stream.position
      dstPtr += bytesRead
      toRead -= bytesRead

      // Return if we have satisfied the request
      if (toRead === 0) {
        // console.log("WeaveDrive: Satisfied request with cache. Returning...")
        return bytesRead
      }
      // console.log("WeaveDrive: Read from cache: ", bytesRead, " Remaining to read: ", toRead)

      const chunkDownloadSz = Math.max(toRead, CACHE_SZ)
      const to = Math.min(stream.node.total_size, stream.position + chunkDownloadSz)
      // console.log("WeaveDrive: fd: ", fd, " Read length: ", toRead, " Reading ahead:", to - toRead - stream.position)

      // Fetch with streaming
      const response = await this.customFetch(`/${stream.node.name}`, {
        method: 'GET',
        redirect: 'follow',
        headers: { Range: `bytes=${stream.position}-${to}` }
      })

      const reader = response.body.getReader()
      let bytesUntilCache = CHUNK_SZ
      let bytesUntilNotify = NOTIFY_SZ
      let downloadedBytes = 0
      let cacheChunks = []

      try {
        while (true) {
          const { done, value: chunkBytes } = await reader.read()
          if (done) break
          // Update the number of downloaded bytes to be _all_, not just the write length
          downloadedBytes += chunkBytes.length
          bytesUntilCache -= chunkBytes.length
          bytesUntilNotify -= chunkBytes.length

          // Write bytes from the chunk and update the pointer if necessary
          const writeLength = Math.min(chunkBytes.length, toRead)
          if (writeLength > 0) {
            // console.log("WeaveDrive: Writing: ", writeLength, " bytes to: ", dstPtr)
            mod.HEAP8.set(chunkBytes.subarray(0, writeLength), dstPtr)
            dstPtr += writeLength
            bytesRead += writeLength
            stream.position += writeLength
            toRead -= writeLength
          }

          if (toRead === 0) {
            // Add excess bytes to our cache
            const chunkToCache = chunkBytes.subarray(writeLength)
            // console.log("WeaveDrive: Cacheing excess: ", chunkToCache.length)
            cacheChunks.push(chunkToCache)
          }

          if (bytesUntilCache <= 0) {
            console.log('WeaveDrive: Chunk size reached. Compressing cache...')
            stream.node.cache = this.addChunksToCache(stream.node.cache, cacheChunks)
            cacheChunks = []
            bytesUntilCache = CHUNK_SZ
          }

          if (bytesUntilNotify <= 0) {
            console.log('WeaveDrive: Downloaded: ', downloadedBytes / stream.node.total_size * 100, '%')
            bytesUntilNotify = NOTIFY_SZ
          }
        }
      } catch (error) {
        console.error('WeaveDrive: Error reading the stream: ', error)
      } finally {
        reader.releaseLock()
      }
      // If we have no cache, or we have not satisfied the full request, we need to download the rest
      // Rebuild the cache from the new cache chunks
      stream.node.cache = this.addChunksToCache(stream.node.cache, cacheChunks)

      // Update the last read position
      stream.lastReadPosition = stream.position
      return bytesRead
    },
    close (fd) {
      let stream = 0
      for (let i = 0; i < FS.streams.length; i++) {
        if (FS.streams[i].fd === fd) {
          stream = FS.streams[i]
        }
      }
      FS.close(stream)
    },

    // Readahead cache functions
    readFromCache (stream, dstPtr, length) {
      // Check if the cache has been invalidated by a seek
      if (stream.lastReadPosition !== stream.position) {
        // console.log("WeaveDrive: Invalidating cache for fd: ", stream.fd, " Current pos: ", stream.position, " Last read pos: ", stream.lastReadPosition)
        stream.node.cache = new Uint8Array(0)
        return 0
      }
      // Calculate the bytes of the request that can be satisfied with the cache
      const cachePartLength = Math.min(length, stream.node.cache.length)
      const cachePart = stream.node.cache.subarray(0, cachePartLength)
      mod.HEAP8.set(cachePart, dstPtr)
      // Set the new cache to the remainder of the unused cache and update pointers
      stream.node.cache = stream.node.cache.subarray(cachePartLength)

      return cachePartLength
    },

    addChunksToCache (oldCache, chunks) {
      // Make a new cache array of the old cache length + the sum of the chunk lengths, capped by the max cache size
      const newCacheLength = Math.min(oldCache.length + chunks.reduce((acc, chunk) => acc + chunk.length, 0), CACHE_SZ)
      const newCache = new Uint8Array(newCacheLength)
      // Copy the old cache to the new cache
      newCache.set(oldCache, 0)
      // Load the cache chunks into the new cache
      let currentOffset = oldCache.length
      for (const chunk of chunks) {
        if (currentOffset < newCacheLength) {
          newCache.set(chunk.subarray(0, newCacheLength - currentOffset), currentOffset)
          currentOffset += chunk.length
        }
      }
      return newCache
    },

    // General helpder functions
    async checkAdmissible (ID) {
      if (mod.mode && mod.mode === 'test') {
        // CAUTION: If the module is initiated with `mode = test` we don't check availability.
        return true
      }

      // Check if we are attempting to load the On-Boot id, if so allow it
      // this was added for AOP 6 Boot loader See: https://github.com/permaweb/aos/issues/342
      const bootTag = this.getTagValue('On-Boot', mod.spawn.tags)
      if (bootTag && (bootTag === ID)) return true

      // Check that this module or process set the WeaveDrive tag on spawn
      const blockHeight = mod.blockHeight
      const moduleExtensions = this.getTagValues('Extension', mod.module.tags)
      const moduleHasWeaveDrive = moduleExtensions.includes('WeaveDrive')
      const processExtensions = this.getTagValues('Extension', mod.spawn.tags)
      const processHasWeaveDrive = moduleHasWeaveDrive || processExtensions.includes('WeaveDrive')

      if (!processHasWeaveDrive) {
        console.log('WeaveDrive: Process tried to call WeaveDrive, but extension not set!')
        return false
      }

      const modes = ['Assignments', 'Individual', 'Library']
      // Get the Availability-Type from the spawned process's Module or Process item
      // First check the module for its defaults
      const moduleAvailabilityType = this.getTagValue('Availability-Type', mod.module.tags)
      const moduleMode = moduleAvailabilityType || 'Assignments' // Default to assignments

      // Now check the process's spawn item. These settings override Module item settings.
      const processAvailabilityType = this.getTagValue('Availability-Type', mod.spawn.tags)
      const processMode = processAvailabilityType || moduleMode

      if (!modes.includes(processMode)) {
        throw Error(`Unsupported WeaveDrive mode: ${processMode}`)
      }

      const attestors = this.serializeStringArr(
        [
          this.getTagValue('Scheduler', mod.spawn.tags),
          ...this.getTagValues('Attestor', mod.spawn.tags)
        ].filter(t => !!t)
      )

      // Init a set of GraphQL queries to run in order to find a valid attestation
      // Every WeaveDrive process has at least the "Assignments" availability check form.
      const assignmentsHaveID = await this.queryHasResult(
        `query {
          transactions(
            owners: ${attestors},
            block: {min: 0, max: ${blockHeight}},
            tags: [
              { name: "Type", values: ["Attestation"] },
              { name: "Message", values: ["${ID}"]}
              { name: "Data-Protocol", values: ["ao"] },
            ]
          ) 
          {
            edges {
              node {
                tags {
                  name
                  value
                }
              }
            }
          }
        }`)

      if (assignmentsHaveID) {
        return true
      }

      if (processMode === 'Individual') {
        const individualsHaveID = await this.queryHasResult(
          `query {
            transactions(
              owners: ${attestors},
              block: {min: 0, max: ${blockHeight}},
              tags: [
                { name: "Type", values: ["Available"]},
                { name: "ID", values: ["${ID}"]}
                { name: "Data-Protocol", values: ["WeaveDrive"] },
              ]
            ) 
            {
              edges {
                node {
                  tags {
                    name
                    value
                  }
                }
              }
            }
          }`)

        if (individualsHaveID) {
          return true
        }
      }

      // Halt message processing if the process requires Library mode.
      // This should signal 'Cannot Process' to the CU, not that the message itself is
      // invalid. Subsequently, the CU should not be slashable for saying that the process
      // execution failed on this message. The CU must also not continue to execute further
      // messages on this process. Attesting to them would be slashable, as the state would
      // be incorrect.
      if (processMode === 'Library') {
        throw Error('This WeaveDrive implementation does not support Library attestations yet!')
      }

      return false
    },

    serializeStringArr (arr = []) {
      return `[${arr.map((s) => `"${s}"`).join(', ')}]`
    },

    getTagValues (key, tags) {
      const values = []
      for (let i = 0; i < tags.length; i++) {
        if (tags[i].name === key) {
          values.push(tags[i].value)
        }
      }
      return values
    },

    getTagValue (key, tags) {
      const values = this.getTagValues(key, tags)
      return values.pop()
    },

    async queryHasResult (query, variables) {
      const json = await this.gqlQuery(query, variables)
        .then((res) => res.json())

      return !!json?.data?.transactions?.edges?.length
    },
    async gqlQuery (query, variables) {
      const options = {
        method: 'POST',
        body: JSON.stringify({ query, variables }),
        headers: { 'Content-Type': 'application/json' }
      }

      return this.customFetch('graphql', options)
    }
  }
}
