import cron from 'node-cron'
import { connect } from '@permaweb/aoconnect'
import chalk from 'chalk'

export async function live(id, { editorMode }) {
  let ct = null
  let cursor = null
  let count = null

  process.stdin.on('keypress', (str, key) => {
    if (ct) {
      ct.stop()
    }
  })

  const checkLive = async () => {
    ct.stop()
    let params = { process: id, limit: "1000" }
    if (cursor) {
      params["from"] = cursor
    }

    //console.log('running every second')
    const results = await connect().results(params)
    const edges = results.edges.filter(function (e) {
      if (e.node.Output?.print === true) {
        return true
      }
      return false
    })
    // simulate messages
    // const edges = [{
    //   node: {
    //     Output: {
    //       prompt: "aos> ",
    //       data: "\u001b[90mNew Message From \u001b[32mMTT...fhM\u001b[90m: \u001b[90mAction = \u001b[34mCron\u001b[0m"
    //     }
    //   }
    // }]

    // --- peek on previous line and if delete line if last prompt.
    // --- key event can detect 
    if (count !== null && edges.length > 0) {
      //console.log(chalk.green(`\n(${edges.length}) new messages...`))
      edges.map(e => {
        process.stdout.write("\u001b[2K");
        process.stdout.write("\u001b[0G" + e.node?.Output?.data)
        process.stdout.write('\n' + e.node?.Output?.prompt || "aos> ")
      })


    }
    count = edges.length
    cursor = edges[edges.length - 1].cursor
    process.nextTick()
    ct.start()
  }

  ct = await cron.schedule('*/2 * * * * *', checkLive)
  return ct
}