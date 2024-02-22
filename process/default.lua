-- default handler for aos
return function (insertInbox)
  return function (msg)
    -- Add Message to Inbox
    insertInbox(msg)

    local txt = Colors.gray .. "New Message From " .. Colors.green .. 
    (msg.From and (msg.From:sub(1,3) .. "..." .. msg.From:sub(-3)) or "unknown") .. Colors.gray .. ": "
    if msg.Action then
      txt = txt .. Colors.gray .. (msg.Action and ("Action = " .. Colors.blue .. msg.Action:sub(1,20)) or "") .. Colors.reset
    else
      txt = txt .. Colors.gray .. "Data = " .. Colors.blue .. (msg.Data and msg.Data:sub(1,20) or "") .. Colors.reset
    end
    -- Print to Output
    print(txt)
  end

end