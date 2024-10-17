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

export function dry() {
  console.log('not implemented')
  return ""

}

export function update() {
  // let luaFiles = fs.readdirSync(__dirname + "../../process")
  //   .filter(n => /\.lua$/.test(n))
  let luaFiles = ['stringify.lua', 'ao.lua', 'utils.lua', 'assignment.lua', 'handlers-utils.lua', 'handlers.lua', 'eval.lua', 'boot.lua', 'process.lua']
    .map(name => {
      const code = fs.readFileSync(__dirname + "../../process/" + name, 'utf-8')
      const mod = name.replace(/\.lua$/, "")
      return template(mod, code)
    })
    .concat(patch())
    .concat(patch2())
    .concat("print([[\nUpdated AOS to version ]] .. require('.process')._version)")
    .join('\n\n')

  luaFiles = `

if not Utils.includes('.crypto.init', Utils.keys(_G.package.loaded)) then
  -- if crypto.init is not installed then return a noop
  _G.package.loaded['.crypto.init'] = { _version = "0.0.0", status = "Not Implemented" }
  return [[
Phase I Completed
Since you have an older version of AOS, you need to update twice. 

Please run [.update] again
  ]]
end

  `
    + luaFiles


  luaFiles = luaFiles + '\n'

  luaFiles = luaFiles + `
-- set ao alias if ao does not exist
if not _G.package.loaded['ao'] then
  _G.package.loaded['ao'] = _G.package.loaded['.ao'] 
end 
  \n`

  return luaFiles
}

function template(mod, code) {
  return `
local function load_${mod.replace("-", "_")}() 
  ${code}
end
_G.package.loaded[".${mod}"] = load_${mod.replace("-", "_")}()
-- print("loaded ${mod}")
  `
}

function patch3() {
  
}

function patch2() {
  return `
Handlers.prepend("Assignment-Check", function (msg)
  return ao.isAssignment(msg) and not ao.isAssignable(msg)
end, function (msg) 
  Send({Target = msg.From, Data = "Assignment is not trusted by this process!"})
  print('Assignment is not trusted! From: ' .. msg.From .. ' - Owner: ' .. msg.Owner)
end)

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
  -- print("Added Patch Handler")
  `
}