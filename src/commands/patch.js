export function patch() {
  const code = `
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
return "Added Patch Handler"
`
  return code
}