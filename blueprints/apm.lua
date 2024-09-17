-- AO Package Manager for easy installation of packages in ao processes
-------------------------------------------------------------------------
--      ___      .______   .___  ___.     __       __    __       ___
--     /   \     |   _  \  |   \/   |    |  |     |  |  |  |     /   \
--    /  ^  \    |  |_)  | |  \  /  |    |  |     |  |  |  |    /  ^  \
--   /  /_\  \   |   ___/  |  |\/|  |    |  |     |  |  |  |   /  /_\  \
--  /  _____  \  |  |      |  |  |  |  __|  `----.|  `--'  |  /  _____  \
-- /__/     \__\ | _|      |__|  |__| (__)_______| \______/  /__/     \__\
--
---------------------------------------------------------------------------
-- APM Registry source code: https://github.com/ankushKun/ao-package-manager
-- CLI tool for managing packages: https://www.npmjs.com/package/apm-tool
-- Web UI for browsing & publishing packages: https://apm.betteridea.dev
-- Built with ❤️ by BetterIDEa

local apm_id = "DKF8oXtPvh3q8s0fJFIeHFyHNM6oKrwMCUrPxEMroak"
local apm_version = "2.0.0"

json = require("json")
base64 = require(".base64")

function Set(list)
  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end

function Hexencode(str)
  return (str:gsub(".", function(char) return string.format("%02x", char:byte()) end))
end

function Hexdecode(hex)
  return (hex:gsub("%x%x", function(digits) return string.char(tonumber(digits, 16)) end))
end

function IsValidVersion(variant)
  return variant:match("^%d+%.%d+%.%d+$")
end

function IsValidPackageName(name)
  return name:match("^[a-zA-Z0-9%-_]+$")
end

function IsValidVendor(name)
  return name and name:match("^@[a-z0-9-]+$")
end

function SplitPackageName(query)
  local vendor, pkgname, version

  -- if only vendor is given
  if query:find("^@%w+$") then
    return query, nil, nil
  end

  -- check if version is provided
  local version_index = query:find("@%d+.%d+.%d+$")
  if version_index then
    version = query:sub(version_index + 1)
    query = query:sub(1, version_index - 1)
  end

  -- check if vendor is provided
  vendor, pkgname = query:match("@(%w+)/([%w%-%_]+)")

  if not vendor then
    pkgname = query
  else
    vendor = "@" .. vendor
  end

  return vendor, pkgname, version
end

-- common error handler
function HandleRun(func, msg)
  local ok, err = pcall(func, msg)
  if not ok then
    local clean_err = err:match(":%d+: (.+)") or err
    print(msg.Action .. " - " .. err)
    -- if not msg.Target == ao.id then
    ao.send({
      Target = msg.From,
      Data = clean_err,
      Result = "error"
    })
    -- end
  end
end

function CheckUpdate(msg)
  local latest_client_version = msg.LatestClientVersion
  if not latest_client_version then
    return
  end
  if latest_client_version and latest_client_version > apm._version then
    print("⚠️ APM update available v:" .. latest_client_version .. " run 'apm.update()'")
  end
end

-------------------------------------------------------------

function DownloadResponseHandler(msg)
  local from = msg.From
  if not from == apm.ID then
    print("Attempt to download from illegal source")
    return
  end

  if not msg.Result == "success" then
    print("Download failed: " .. msg.Name)
    return
  end

  local source = msg.Data
  local name = msg.Name
  local version = msg.Version
  local warnings = msg.Warnings         -- {ModifiesGlobalState:boolean, Message:boolean}
  local dependencies = msg.Dependencies -- {[name:string] = {version:string}}

  if source then
    source = Hexdecode(source)
  end

  if warnings and warnings.ModifiesGlobalState then
    print("⚠️ Package modifies global state")
  end

  if warnings and warnings.Message then
    print("⚠️ " .. warnings.Message)
  end

  -- if vendor is @apm remove it and just keep the name
  local loaded_name = name:match("^@apm/(.+)$") or name

  local func, err = load(string.format([[
        local function _load()
            %s
        end
        _G.package.loaded["%s"] = _load()
    ]], source, loaded_name))
  if not func then
    error("Error compiling load function: " .. err)
  end
  func()
  print("✅ Downloaded " .. name .. "@" .. version)
  apm.installed[name] = version

  if dependencies then
    dependencies = json.decode(dependencies) -- "dependencies": {"test-pkg": {"version": "1.0.0"}}
  end

  for dep, depi in pairs(dependencies) do
    -- install dependency and make sure there is no circular install
    if not apm.installed[dep] == depi.version then
      print("ℹ️ Installing dependency " .. dep .. "@" .. depi.version)
      apm.install(dep)
    end
  end

  CheckUpdate(msg)
end

Handlers.add(
  "APM.DownloadResponse",
  Handlers.utils.hasMatchingTag("Action", "APM.DownloadResponse"),
  function(msg)
    HandleRun(DownloadResponseHandler, msg)
  end
)

-------------------------------------------------------------

function SearchResponseHandler(msg)
  if msg.From ~= apm.ID then
    print("Attempt to search from illegal source")
    return
  end

  local result = msg.Result
  if not result == "success" then
    print("Search failed: " .. msg.Data)
    return
  end

  local res = json.decode(msg.Data)
  if #res == 0 then
    print("No packages found")
    return
  end

  local p = "\n"
  for _, pkg in ipairs(res) do
    p = p .. pkg.Vendor .. "/" .. pkg.Name .. " | " .. pkg.Description .. "\n"
  end
  print(p)

  CheckUpdate(msg)
end

Handlers.add(
  "APM.SearchResponse",
  Handlers.utils.hasMatchingTag("Action", "APM.SearchResponse"),
  function(msg)
    HandleRun(SearchResponseHandler, msg)
  end
)

-------------------------------------------------------------

function InfoResponseHandler(msg)
  if msg.From ~= apm.ID then
    print("Attempt to get info from illegal source")
    return
  end

  local result = msg.Result
  if not result == "success" then
    print("Info failed: " .. msg.Data)
    return
  end

  local res = json.decode(msg.Data)
  if not res then
    print("No info found")
    return
  end

  print("📦 " .. Colors.green .. res.Vendor .. "/" .. res.Name .. Colors.reset)
  print("📄 Description    : " .. Colors.green .. res.Description .. Colors.reset)
  print("🔖 Latest Version : " .. Colors.green .. res.Version .. Colors.reset)
  print("📥 Installs       : " .. Colors.green .. res.TotalInstalls .. Colors.reset)
  print("🔗 APM Url        : " .. Colors.green .. "https://apm.betteridea.dev/pkg?id=" .. res.PkgID .. Colors.reset)
  print("🔗 Repository Url : " .. Colors.green .. res.Repository .. Colors.reset)

  CheckUpdate(msg)
end

Handlers.add(
  "APM.InfoResponse",
  Handlers.utils.hasMatchingTag("Action", "APM.InfoResponse"),
  function(msg)
    HandleRun(InfoResponseHandler, msg)
  end
)

-------------------------------------------------------------

function UpdateResponseHandler(msg)
  print("Update requested")
  local from = msg.From
  if not from == apm.ID then
    print("Attempt to update from illegal source")
    return
  end

  if not msg.Result == "success" then
    print("Update failed: " .. msg.Data)
    return
  end

  local source = msg.Data
  local version = msg.Version

  if source then
    source = Hexdecode(source)
  end

  local func, err = load(string.format([[
        local function _load()
            %s
        end
        -- apm = _load()
    ]], source))
  if not func then
    error("Error compiling load function: " .. err)
  end
  func()

  apm._version = version
  print("✅ Updated APM to v:" .. version)
  print("Please use 'apm' namespace for all commands")
end

Handlers.add(
  "APM.UpdateResponse",
  Handlers.utils.hasMatchingTag("Action", "APM.UpdateResponse"),
  function(msg)
    HandleRun(UpdateResponseHandler, msg)
  end
)

-------------------------------------------------------------

apm = {}
apm.ID = apm_id
apm._version = apm._version or apm_version
apm.installed = apm.installed or {}

function apm.install(name)
  local vendor, pkgname, version = SplitPackageName(name)
  if not vendor then
    vendor = "@apm"
  end
  if not IsValidVendor(vendor) then
    return error("Invalid vendor name")
  end
  if not IsValidPackageName(pkgname) then
    return error("Invalid package name")
  end
  if version and not IsValidVersion(version) then
    return error("Invalid version")
  end

  local pkgnv = vendor .. "/" .. pkgname
  local pkg = apm.installed[pkgnv]
  if pkg then
    return error("Package already installed")
  end

  if version then
    pkgnv = pkgnv .. "@" .. version
  end

  Send({
    Target = apm.ID,
    Action = "APM.Download",
    Data = pkgnv
  })
  return "📦 Download requested for " .. pkgnv
end

function apm.search(query)
  if not query then
    return error("No search query provided")
  end

  Send({
    Target = apm.ID,
    Action = "APM.Search",
    Data = query
  })
  return "🔍 Search requested for " .. query
end

function apm.update()
  Send({
    Target = apm.ID,
    Action = "APM.Update"
  })
  return "📦 Update requested"
end

function apm.info(query)
  if not query then
    return error("No info query provided")
  end

  Send({
    Target = apm.ID,
    Action = "APM.Info",
    Data = query
  })
  return "📦 Info requested for " .. query
end

function apm.uninstall(name)
  local vendor, pkgname
  _ = SplitPackageName(name)
  if not vendor then
    vendor = "@apm"
  end
  if not IsValidVendor(vendor) then
    return error("Invalid vendor name")
  end
  if not IsValidPackageName(pkgname) then
    return error("Invalid package name")
  end

  local pkgnv = vendor .. "/" .. pkgname
  local pkg = apm.installed[pkgnv]

  if not pkg then
    return error("Package not installed")
  end


  apm.installed[pkgnv] = nil
  if vendor == "@apm" then
    _G.package.loaded[name] = nil
  else
    _G.package.loaded[pkgnv] = nil
  end
  return "📦 Uninstalled " .. pkgnv
end

print("📦 APM client v" .. apm._version .. " loaded")
