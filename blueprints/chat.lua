DevChat = {}

DevChat.Router = "8MGp9kOU4JYxAlPT1AyL7O3cedd97y-w8X4ciBsf_Xo"
DevChat.InitRoom = "6I1JBBc9SOMtqFxlX7OoYgsMh7QeZk2fFwUCHTUqshg"
DevChat.LastSend = DevChat.LastSend or DevChat.InitRoom

DevChat.LastReceive = {
    Room = DevChat.InitRoom,
    Sender = nil
}

DevChat.InitRooms = { [DevChat.InitRoom] = "Getting-Started" }
DevChat.Rooms = DevChat.Rooms or DevChat.InitRooms

DevChat.Confirmations = DevChat.Confirmations or true

-- Helper function to go from roomName => address
DevChat.findRoom =
    function(target)
        for address, name in pairs(DevChat.Rooms) do
            if target == name then
                return address
            end
        end
    end

DevChat.add =
    function(...)
        local arg = {...}
        ao.send({
            Target = DevChat.Router,
            Action = "Register",
            Name = arg[1] or Name,
            Address = arg[2] or ao.id
        })
    end

List =
    function()
        ao.send({ Target = DevChat.Router, Action = "Get-List" })
        return(Colors.gray .. "Getting the room list from the DevChat index..." .. Colors.reset)
    end

Join =
    function(id, ...)
        local arg = {...}
        local addr = DevChat.findRoom(id) or id
        local nick = arg[1] or ao.id
        ao.send({ Target = addr, Action = "Register", Nickname = nick or Name })
        return(
            Colors.gray ..
             "Registering with room " ..
            Colors.blue .. id .. 
            Colors.gray .. "..." .. Colors.reset)
    end

Say =
    function(text, ...)
        local arg = {...}
        local id = arg[1]
        if id ~= nil then
            -- Remember the new room for next time.
            DevChat.LastSend = DevChat.findRoom(id) or id
        end
        local name = DevChat.Rooms[DevChat.LastSend] or id
        ao.send({ Target = DevChat.LastSend, Action = "Broadcast", Data = text })
        if DevChat.Confirmations then
            return(Colors.gray .. "Broadcasting to " .. Colors.blue ..
                name .. Colors.gray .. "..." .. Colors.reset)
        else
            return ""
        end
    end

Tip =
    function(...) -- Recipient, Target, Qty
        local arg = {...}
        local room = arg[2] or DevChat.LastReceive.Room
        local roomName = DevChat.Rooms[room] or room
        local qty = tostring(arg[3] or 1)
        local recipient = arg[1] or DevChat.LastReceive.Sender
        ao.send({
            Action = "Transfer",
            Target = room,
            Recipient = recipient,
            Quantity = qty
        })
        return(Colors.gray .. "Sent tip of " ..
            Colors.green .. qty .. Colors.gray ..
            " to " .. Colors.red .. recipient .. Colors.gray ..
            " in room " .. Colors.blue .. roomName .. Colors.gray ..
            "."
        )
    end

Replay =
    function(...) -- depth, room
        local arg = {...}
        local room = nil
        if arg[1] then
            room = DevChat.findRoom(arg[2]) or arg[2]
        else
            room = DevChat.LastReceive.Room
        end
        local roomName = DevChat.Rooms[room] or room
        local depth = arg[1] or 3

        ao.send({
            Target = room,
            Action = "Replay",
            Depth = tostring(depth)
        })
        return(
            Colors.gray ..
             "Requested replay of the last " ..
            Colors.green .. depth .. 
            Colors.gray .. " messages from " .. Colors.blue ..
            roomName .. Colors.reset .. ".")
    end

Leave =
    function(id)
        local addr = DevChat.findRoom(id) or id
        ao.send({ Target = addr, Action = "Unregister" })
        return(
            Colors.gray ..
             "Leaving room " ..
            Colors.blue .. id ..
            Colors.gray .. "..." .. Colors.reset)
    end


Handlers.add(
    "DevChat-Broadcasted",
    Handlers.utils.hasMatchingTag("Action", "Broadcasted"),
    function (m)
        local shortRoom = DevChat.Rooms[m.From] or string.sub(m.From, 1, 6)
        if m.Broadcaster == ao.id then
            if DevChat.Confirmations == true then
                print(
                    Colors.gray .. "[Received confirmation of your broadcast in "
                    .. Colors.blue .. shortRoom .. Colors.gray .. ".]"
                    .. Colors.reset)
            end
        end
        local nick = string.sub(m.Nickname, 1, 10)
        if m.Broadcaster ~= m.Nickname then
            nick = nick .. Colors.gray .. "#" .. string.sub(m.Broadcaster, 1, 3)
        end
        print(
            "[" .. Colors.red .. nick .. Colors.reset
            .. "@" .. Colors.blue .. shortRoom .. Colors.reset
            .. "]> " .. Colors.green .. m.Data .. Colors.reset)

        DevChat.LastReceive.Room = m.From
        DevChat.LastReceive.Sender = m.Broadcaster
    end
)

Handlers.add(
    "DevChat-List",
    function(m)
        if m.Action == "Room-List" and m.From == DevChat.Router then
            return true
        end
        return false
    end,
    function(m)
        local intro = "👋 The following rooms are currently available on DevChat:\n\n"
        local rows = ""
        DevChat.Rooms = DevChat.InitRooms

        for i = 1, #m.TagArray do
            local filterPrefix = "Room-" -- All of our room tags start with this
            local tagPrefix = string.sub(m.TagArray[i].name, 1, #filterPrefix)
            local name = string.sub(m.TagArray[i].name, #filterPrefix + 1, #m.TagArray[i].name)
            local address = m.TagArray[i].value

            if tagPrefix == filterPrefix then
                rows = rows .. Colors.blue .. "        " .. name .. Colors.reset .. "\n"
                DevChat.Rooms[address] = name
            end
        end

        print(
            intro .. rows .. "\nJoin a chat by running `Join(\"chatName\"[, \"yourNickname\"])`! You can leave chats with `Leave(\"name\")`.")
    end
)

if DevChatRegistered == nil then
    DevChatRegistered = true
    Join(DevChat.InitRoom)
end

function help()
    return(
        Colors.blue .. "\n\nWelcome to ao DevChat v0.1!\n\n" .. Colors.reset ..
        "DevChat is a simple service that helps the ao community communicate as we build our new computer.\n" ..
        "The interface is simple. Run...\n\n" ..
        Colors.green .. "\t\t`List()`" .. Colors.reset .. " to see which rooms are available.\n" .. 
        Colors.green .. "\t\t`Join(\"RoomName\")`" .. Colors.reset .. " to join a room.\n" .. 
        Colors.green .. "\t\t`Say(\"Msg\", \"RoomName\") or Say(\"Msg\", \"RoomName1\", \"RoomName2\")`" .. Colors.reset .. " to post to a room (remembering your last choice for next time).\n" ..
        Colors.green .. "\t\t`Replay(Count, \"RoomName\") e.g. Replay(1, \"Getting-Started\")`" .. Colors.reset .. " to reprint the most recent messages from a chat.\n" ..
        Colors.green .. "\t\t`Leave(\"RoomName\")`" .. Colors.reset .. " at any time to unsubscribe from a chat.\n" ..
        Colors.green .. "\t\t`Tip([\"Recipient\"])`" .. Colors.reset .. " to send a token from the chatroom to the sender of the last message.\n\n" ..
        "You have already been registered to the " .. Colors.blue .. DevChat.Rooms[DevChat.InitRoom] .. Colors.reset .. ".\n" ..
        "Have fun, be respectful, and remember: Cypherpunks ship code! 🫡")
end

return help()