-- AO Package Manager for easy installation of packages in ao processes
-- This blueprint fetches the latest APM client from the APM registry and installs it
-------------------------------------------------------------------------
--      ___      .______   .___  ___.     __       __    __       ___
--     /   \     |   _  \  |   \/   |    |  |     |  |  |  |     /   \
--    /  ^  \    |  |_)  | |  \  /  |    |  |     |  |  |  |    /  ^  \
--   /  /_\  \   |   ___/  |  |\/|  |    |  |     |  |  |  |   /  /_\  \
--  /  _____  \  |  |      |  |  |  |  __|  `----.|  `--'  |  /  _____  \
-- /__/     \__\ | _|      |__|  |__| (__)_______| \______/  /__/     \__\
--
---------------------------------------------------------------------------
-- APM Registry source code: https://github.com/betteridea-dev/ao-package-manager
-- CLI tool for managing packages: https://www.npmjs.com/package/apm-tool
-- Web UI for browsing & publishing packages: https://apm.betteridea.dev
-- Built with ❤️ by BetterIDEa


local apm_id = "DKF8oXtPvh3q8s0fJFIeHFyHNM6oKrwMCUrPxEMroak"

function Hexencode(str)
    return (str:gsub(".", function(char) return string.format("%02x", char:byte()) end))
end

function Hexdecode(hex)
    return (hex:gsub("%x%x", function(digits) return string.char(tonumber(digits, 16)) end))
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

local function InstallResponseHandler(msg)
    local from = msg.From
    if not from == apm_id then
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
        _load()
    ]], source))
    if not func then
        error("Error compiling load function: " .. err)
    end
    func()

    apm._version = version
    -- print("✅ Installed APM v:" .. version)
end

Handlers.once(
    "APM.UpdateResponse",
    Handlers.utils.hasMatchingTag("Action", "APM.UpdateResponse"),
    function(msg)
        HandleRun(InstallResponseHandler, msg)
    end
)

Send({
    Target = apm_id,
    Action = "APM.Update"
})
print("📦 Loading APM...")
