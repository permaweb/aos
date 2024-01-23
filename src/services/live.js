import cron from 'node-cron'
import { connect } from '@permaweb/aoconnect'
import chalk from 'chalk'

export async function live(id) {
  let cursor = null
  let count = null
  const checkLive = async () => {
    let params = { process: id, limit: "1000" }
    if (cursor) {
      params["from"] = cursor
    }
    //console.log('running every second')
    const results = await connect().results(params)
    const edges = results.edges.filter(function (e) {
      if (e.node.Output?.data === undefined) {
        return true
      }
      return false
    })
    if (count !== null && edges.length > 0) {
      console.log(chalk.green(`\n(${edges.length}) new messages...`))
      console.log('[press enter] to reset cursor...')
    }
    count = edges.length
    cursor = edges[edges.length - 1].cursor
    process.nextTick()
  }

  return cron.schedule('*/2 * * * * *', checkLive)
}