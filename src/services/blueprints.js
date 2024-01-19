import fs from 'fs'
import path from 'path'
import * as url from 'url';
import chalk from 'chalk'


const __dirname = url.fileURLToPath(new URL('.', import.meta.url));


export function blueprints() {
  const token = fs.readFileSync(path.resolve(__dirname + '../../blueprints/token.lua'), 'utf-8')
  const dao = fs.readFileSync(path.resolve(__dirname + '../../blueprints/dao.lua'), 'utf-8')
  // const bot = fs.readFileSync(path.resolve(__dirname + '../../blueprints/bot.lua'), 'utf-8')
  const chatroom = fs.readFileSync(path.resolve(__dirname + '../../blueprints/chatroom.lua'), 'utf-8')
  fs.writeFileSync(path.resolve(process.cwd() + '/token.lua'), token)
}