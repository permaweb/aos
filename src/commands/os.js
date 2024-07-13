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
import chalk from 'chalk'


let __dirname = url.fileURLToPath(new URL('.', import.meta.url));
if (os.platform() === 'win32') {
  __dirname = __dirname.replace(/\\/g, "/").replace(/^[A-Za-z]:\//, "/")
}
export function update() {
  const luaFiles = fs.readdirSync(__dirname + "/../../process")
    .filter(n => /\.lua$/.test(n))
    //.filter((n, i) => i === 7)
    .map(name => {
      const code = fs.readFileSync(__dirname + "/../../process/" + name, 'utf-8')
      const mod = name.replace(/\.lua$/, "")

      return template(mod, code)
    })
    .concat(patch())
    .join('\n\n')

  return luaFiles + '\nreturn ao.outbox.Output.data'
}

function template(mod, code) {
  return `
local function load_${mod.replace("-", "_")} () 
  ${code}
end
_G.package.loaded[".${mod}"] = load_${mod.replace("-", "_")} ()
print('loaded ${mod}')

  `
}

function patch() {
  return `
  local AO_TESTNET = 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY'
  local SEC_PATCH = 'sec-patch-6-5-2024'
  
  if not Utils.includes(AO_TESTNET, ao.authorities) then
    table.insert(ao.authorities, AO_TESTNET)
  end
  if not Utils.includes(SEC_PATCH, Utils.map(Utils.prop('name'), Handlers.list)) then
    Handlers.prepend(SEC_PATCH, 
      function (msg)
        return msg.From ~= msg.Owner and not ao.isTrusted(msg)
      end,
      function (msg)
        Send({Target = msg.From, Data = "Message is not trusted."})
        print("Message is not trusted. From: " .. msg.From .. " - Owner: " .. msg.Owner)
      end
    )
  end
  print("Added Patch Handler")
  `
}