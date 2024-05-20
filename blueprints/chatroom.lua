Members = Members or {}

function valueExists(arr, val)
  local str = table.concat(arr, ",")
  return string.match(","..str..",", ","..val..",") ~= nil
end

Handlers.add(
  "register",
  Handlers.utils.hasMatchingTag("Action", "Register"),
  function (msg)
    if valueExists(myArray, searchValue) then
        Handlers.utils.reply("Have registered, not need register again")(msg)
    else
        table.insert(Members, msg.From)
        Handlers.utils.reply("registered")(msg)
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
    for _, recipient in ipairs(Members) do
      ao.send({Target = recipient, Data = msg.Data})
    end
    Handlers.utils.reply("Broadcasted.")(msg)
  end
)