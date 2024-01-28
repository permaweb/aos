import cron from 'node-cron'
import { connect } from '@permaweb/aoconnect'
import chalk from 'chalk'
import fs from 'fs'
import path from 'path'
import os from 'os'
import { uniqBy, prop, keys } from 'ramda'

export async function live(id) {
  let ct = null
  let cu = null
  let cursor = null
  let count = null
  let cursorFile = path.resolve(os.homedir() + `/.${id}.txt`)

  if (fs.existsSync(cursorFile)) {
    cursor = fs.readFileSync(cursorFile, 'utf-8')
  }

  process.stdin.on('keypress', (str, key) => {
    if (ct) {
      ct.stop()
    }
  })

  const checkLive = async () => {
    cu.stop()
    let params = { process: id, limit: "1000" }
    if (cursor) {
      params["from"] = cursor
    }

    const results = await connect().results(params)

    const edges = uniqBy(prop('cursor'))(results.edges.filter(function (e) {
      if (e.node?.Output?.print === true) {
        return true
      }
      if (e.cursor === cursor) {
        return false
      }
      return false
    }))

    // --- peek on previous line and if delete line if last prompt.
    // --- key event can detect 
    // count !== null && 
    if (count !== null && edges.length > 0) {
      edges.map(e => {
        if (!globalThis.alerts[e.cursor]) {
          globalThis.alerts[e.cursor] = e.node?.Output
        }
      })


    }
    count = edges.length
    cursor = results.edges[results.edges.length - 1].cursor
    fs.writeFileSync(cursorFile, cursor)
    process.nextTick()
    cu.start()
  }
  cu = await cron.schedule('*/2 * * * * *', checkLive)

  function printLive() {
    keys(globalThis.alerts).map(k => {
      if (globalThis.alerts[k].print) {
        globalThis.alerts[k].print = false
        process.stdout.write("\u001b[2K");
        process.stdout.write("\u001b[0G" + globalThis.alerts[k].data)

        globalThis.prompt = globalThis.alerts[k].prompt || "aos> "

        process.stdout.write('\n' + globalThis.prompt || "aos> ")
      }
    })

  }

  ct = await cron.schedule('*/2 * * * * *', printLive)
  return ct
}