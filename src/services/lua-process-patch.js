import { LUA_EXECUTION_DEVICE } from './process-type.js'

/**
 * Compatibility patch for the currently pinned Hyper-AOS Lua module.
 *
 * The original evaluator is retained on the Handlers system table. Hyper-AOS
 * excludes that table when serializing process state, so a restored VM installs
 * the wrapper again while a warm VM does not wrap it recursively.
 */
export const LUA_PROCESS_OUTPUT_PATCH = String.raw`
if _G.Handlers and type(_G.Handlers.evaluate) == "function" then
  if type(_G.Handlers.__aos_original_evaluate) ~= "function" then
    _G.Handlers.__aos_original_evaluate = _G.Handlers.evaluate
  end

  local original_evaluate = _G.Handlers.__aos_original_evaluate
  _G.Handlers.evaluate = function(msg, env)
    local previous_output = type(_G._OUTPUT) == "string" and _G._OUTPUT or ""
    local result = original_evaluate(msg, env)

    if _G.results and type(_G.results.output) == "table" and type(_G.prompt) == "function" then
      local prompt_ok, next_prompt = pcall(_G.prompt)
      if prompt_ok then
        _G.results.output.prompt = next_prompt
      end
    end

    if result == true then
      local current_output = type(_G._OUTPUT) == "string" and _G._OUTPUT or previous_output
      local emitted = string.sub(current_output, #previous_output + 1)
      if string.sub(emitted, -1) == "\n" then
        emitted = string.sub(emitted, 1, -2)
      end
      _G._OUTPUT = previous_output
      return emitted
    end

    return result
  end
end

_G.meta = _G.meta or {}
if type(_G.eval) == "function" then
  if type(_G.meta.__aos_original_eval) ~= "function" then
    _G.meta.__aos_original_eval = _G.eval
  end

  local original_eval = _G.meta.__aos_original_eval
  _G.eval = function(msg)
    local result, eval_error = original_eval(msg)
    if result == nil and eval_error == nil then
      return ""
    end
    return result, eval_error
  end
end

function _G.meta.printNewMessage(msg)
  local colors = _G.colors or {}
  local reset = colors.reset or ""
  local from = msg.from or msg.From
  local from_display = from and tostring(from) or "unknown"

  if from and #from_display > 6 then
    from_display = string.sub(from_display, 1, 3) .. "..." .. string.sub(from_display, -3)
  end

  local action = msg.action or msg.Action
  if action == nil and type(msg.body) == "table" then
    action = msg.body.action or msg.body.Action
  end

  local label = "Action"
  local content = action
  if content == nil or content == "" then
    label = "Data"
    content = msg.data or msg.Data
    if content == nil and type(msg.body) ~= "table" then
      content = msg.body
    end
  end

  if type(content) == "table" and type(_G.stringify) == "function" then
    content = _G.stringify(content)
  else
    content = tostring(content or "")
  end

  if #content > 20 then
    content = string.sub(content, 1, 20)
  end

  return "New Message From " ..
         (colors.green or "") .. from_display .. reset ..
         ": " .. label .. " = " ..
         (colors.blue or "") .. content .. reset
end

function send(msg)
  assert(type(msg) == "table", "msg should be a table")
  _G.results = _G.results or {}
  _G.results.outbox = _G.results.outbox or {}
  table.insert(_G.results.outbox, msg)
  return "Message Sent"
end
`

const PROCESS_VERSION_EXPRESSION = 'return require(\'.process\')._version'

export function processVersionExpression (executionDevice) {
  if (executionDevice !== LUA_EXECUTION_DEVICE) return PROCESS_VERSION_EXPRESSION

  return `${LUA_PROCESS_OUTPUT_PATCH}\n${PROCESS_VERSION_EXPRESSION}`
}
