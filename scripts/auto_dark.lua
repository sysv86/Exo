local user_settings = require("user_settings")
local Wallpaper = require("scripts.wallpaper")

local M = {}

--- Compares the current time against the configured window and flips the theme.
function M.auto_dark()
    local options = user_settings.appearance.wallcolors.auto_dark
    if not options.enabled then
        return
    end

    local now = os.date("*t")
    local current = now.hour * 60 + now.min
    local start_time = math.floor(options.start_hour) * 60 + math.floor(options.start_min)
    local end_time = math.floor(options.end_hour) * 60 + math.floor(options.end_min)

    local dark_mode = user_settings.appearance.wallcolors.dark_mode

    local should_be_dark
    if start_time < end_time then
        should_be_dark = (current >= start_time and current <= end_time)
    else
        should_be_dark = (current >= start_time or current <= end_time)
    end

    if should_be_dark and not dark_mode then
        Wallpaper.set_dark_mode(true)
    elseif (not should_be_dark) and dark_mode then
        Wallpaper.set_dark_mode(false)
    end
end

--- Enables/disables auto dark mode and applies it immediately.
---@param active boolean
function M.set_auto_dark(active)
    user_settings.appearance.wallcolors.auto_dark.enabled = active
    M.auto_dark()
end

return M
