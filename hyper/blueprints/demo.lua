Balances = Balances or {}
Tokens = Tokens or {"0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc"}

Handlers.add("Credit-Notice", function (req)
  Send({ sender = req.body.sender, data = "Hello World" })
  print(req.body.sender)
end)


print('Loaded ledger blueprint.')
