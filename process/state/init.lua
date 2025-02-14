local state = {}
function state.init()
  require(".src.globals")
  require(".state.balances")
  require(".state.arns_records")
  require(".state.primary_names")
  require(".state.gateways")
  require(".state.delegates")
end

return state
