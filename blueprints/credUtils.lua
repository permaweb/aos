CRED_PROCESS = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"

_CRED = { balance = "Your CRED balance has not been checked yet. Updating now." }

local credMeta = {
    __index = function(t, key)
        -- sends CRED balance request
        if key == "update" then
            Send({ Target = CRED_PROCESS, Action = "Balance", Tags = { Target = ao.id } })
            return "Balance update requested."
            -- prints local CRED balance, requests it if not set
        elseif key == "balance" then
            if _CRED.balance == "Your CRED balance has not been checked yet. Updating now." then
                Send({ Target = CRED_PROCESS, Action = "Balance", Tags = { Target = ao.id } })
            end
            return _CRED.balance
            -- prints CRED process ID
        elseif key == "process" then
            return CRED_PROCESS
            -- tranfers CRED
        elseif key == "send" then
            return function(target, amount)
                -- ensures amount is string
                amount = tostring(amount)
                print("sending " .. amount .. "CRED to " .. target)
                Send({ Target = CRED_PROCESS, Action = "Transfer", Recipient = target, Quantity = amount })
            end
        else
            return nil
        end
    end
}


CRED = setmetatable({}, credMeta)

-- Function to evaluate if a message is a balance update
local function isCredBalanceMessage(msg)
    if msg.From == CRED_PROCESS and msg.Tags.Balance then
        return true
    else
        return false
    end
end

-- Function to evaluate if a message is a Debit Notice
local function isDebitNotice(msg)
    if msg.From == CRED_PROCESS and msg.Tags.Action == "Debit-Notice" then
        return true
    else
        return false
    end
end

-- Function to evaluate if a message is a Credit Notice
local function isCreditNotice(msg)
    if msg.From == CRED_PROCESS and msg.Tags.Action == "Credit-Notice" then
        return true
    else
        return false
    end
end

local function formatBalance(balance)
    -- Ensure balance is treated as a string
    balance = tostring(balance)
    -- Check if balance length is more than 3 to avoid unnecessary formatting
    if #balance > 3 then
        -- Insert dot before the last three digits
        balance = balance:sub(1, -4) .. "." .. balance:sub(-3)
    end
    return balance
end

-- Handles Balance messages
Handlers.add(
    "UpdateCredBalance",
    isCredBalanceMessage,
    function(msg)
        local balance = nil
        if msg.Tags.Balance then
            balance = msg.Tags.Balance
        end
        -- Format the balance if it's not set
        if balance then
            -- Format the balance by inserting a dot after the first three digits from the right
            local formattedBalance = formatBalance(balance)
            _CRED.balance = formattedBalance
            print("CRED Balance updated: " .. _CRED.balance)
        else
            print("An error occurred while updating CRED balance")
        end
    end
)

-- Handles Debit notices
Handlers.add(
    "CRED_Debit",
    isDebitNotice,
    function(msg)
        print(msg.Data)
    end
)

-- Handles Credit notices
Handlers.add(
    "CRED_Credit",
    isCreditNotice,
    function(msg)
        print(msg.Data)
    end
)
