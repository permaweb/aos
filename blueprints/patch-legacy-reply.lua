local function patchReply(msg)
  if not msg.reply then
    msg.reply = function (replyMsg) 
      replyMsg.Target = msg["Reply-To"] or (replyMsg.Target or msg.From)
      replyMsg["X-Reference"] = msg["X-Reference"] or msg.Reference or ""
      replyMsg["X-Origin"] = msg["X-Origin"] or ""

      return ao.send(replyMsg)
    end
  end
end

Handlers.prepend("_patch_reply", function (msg) return "continue" end, patchReply)