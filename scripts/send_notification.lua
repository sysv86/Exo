local ignis = require("ignis")
local utils = ignis.utils

local function shell_quote(text)
    return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end

--- Sends a notification.
---@param summary string
---@param body? string
function send_notification(summary, body)
    local command
    if body then
        command = string.format("notify-send -a %s %s %s",
            shell_quote("Exo"), shell_quote(summary), shell_quote(body))
    else
        command = string.format("notify-send -a %s %s",
            shell_quote("Exo"), shell_quote(summary))
    end
    utils.exec_sh_async(command)
end

return send_notification
