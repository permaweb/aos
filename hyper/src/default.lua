local json = require('.json')
-- default handler for aos
return function (insertInbox)
  return function (msg)
    -- Add Message to Inbox
    insertInbox(msg)

    local colors = Colors or {}
    local reset = colors.reset or ""
    local from = msg.from or msg.From
    local fromDisplay = from and tostring(from) or "unknown"
    fromDisplay = from and #fromDisplay > 6
      and (fromDisplay:sub(1, 3) .. "..." .. fromDisplay:sub(-3))
      or fromDisplay
    local action = msg.action or msg.Action
    local label = "Action"
    local content = action

    if content == nil or content == "" then
      label = "Data"
      content = msg.data or msg.Data or ""
      if type(content) == 'table' then
        content = json.encode(content)
      else
        content = tostring(content)
      end
    else
      content = tostring(content)
    end

    print("New Message From " .. (colors.green or "") .. fromDisplay .. reset ..
      ": " .. label .. " = " .. (colors.blue or "") .. content:sub(1, 20) .. reset)
  end

end
