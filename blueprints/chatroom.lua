Members = Members or {}

Handlers.add(
  "register",
  Handlers.utils.hasMatchingTag("Action", "Register"),
  function (msg)
    local found = false
    for _, member in ipairs(Members) do
      if member == msg.From then
        found = true
        break
      end
    end
    
    if not found then
      table.insert(Members, msg.From)
      Handlers.utils.reply("Registered.")(msg)
    else
      Handlers.utils.reply("Already registered.")(msg)
    end
  end
)

Handlers.add(
  "unregister",
  Handlers.utils.hasMatchingTag("Action", "Unregister"),
  function (msg)
    local found = false
    for i, v in ipairs(Members) do
        if v == msg.From then
            table.remove(Members, i)
            Handlers.utils.reply("Unregistered")(msg)
            found = true
            break
        end
    end
    if not found then
        Handlers.utils.reply("Not registered")(msg)
    end
  end
)

Handlers.add(
  "broadcast",
  Handlers.utils.hasMatchingTag("Action", "Broadcast"),
  function (msg)
    local haveSentRecords = {}
    for _, recipient in ipairs(Members) do
      if not haveSentRecords[recipient] then
        ao.send({Target = recipient, Data = msg.Data})
        haveSentRecords[recipient] = true
      end
    end
    Handlers.utils.reply("Broadcasted.")(msg)
  end
)
