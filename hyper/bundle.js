/**
 * os update
 * 
 * this command will load all of the latest aos process modules into memory on an existing 
 * process. This should allow us to have a better devX experience when building the os, 
 * as well as make it easier for users to update their processes.
 */
import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import * as url from 'url'


let __dirname = url.fileURLToPath(new URL('.', import.meta.url));
if (os.platform() === 'win32') {
  __dirname = __dirname.replace(/\\/g, "/").replace(/^[A-Za-z]:\//, "/")
}

export function dry() {
  console.log('not implemented')
  return ""

}

export function update() {
  // let luaFiles = fs.readdirSync(__dirname)
  //   .filter(n => /\.lua$/.test(n))
  let luaFiles = ['json.lua', 'stringify.lua', 'eval.lua',
    'utils.lua', 'handlers-utils.lua', 'handlers.lua',
    'dump.lua', 'pretty.lua', 'chance.lua', 'boot.lua',
    'default.lua', 'ao.lua', 'base64.lua', 
    'state.lua', 'process.lua'  ]
    .map(name => {
      const code = fs.readFileSync(__dirname + 'src/' + name, 'utf-8')
      const mod = name.replace(/\.lua$/, "")
      return template(mod, code)
    })
    .join('\n\n')
  let main = fs.readFileSync(__dirname + 'src/' + "main.lua", "utf-8")
  luaFiles += '\n\n' + main
  let args = process.argv.slice(2)
  if (args[0]) {
    luaFiles += '\n\n' + fs.readFileSync(__dirname + 'blueprints/' + args[0], 'utf-8')
  }
  return luaFiles
}

function template(mod, code) {
  return `
local function load_${mod.replace("-", "_")}() 
  ${code}
end
_G.package.loaded[".${mod}"] = load_${mod.replace("-", "_")}()
print("loaded ${mod}")
  `
}


console.log(
	update()
)


