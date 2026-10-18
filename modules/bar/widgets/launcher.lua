local ignis = require("ignis")
local m3 = require("modules.m3components")
local widgets = ignis.widgets
local window_manager = ignis.WindowManager.get_default()

local Launcher = {}
Launcher.__index = Launcher

function Launcher.new()
    local self = setmetatable({}, Launcher)
    self.button = widgets.Button({
        child = widgets.Label({ label = "apps", css_classes = { "m3-icon" } }),
        css_classes = { "launcher-button" },
        on_click = function()
            self:launch()
        end,
        hexpand = true,
        vexpand = true,
        halign = "fill",
        valign = "fill",
    })

    m3.enhance_button(self.button, {
        ink = "primary",
        hover_bg = "primary",
        hover_ink = "on_primary",
        radius = { rest = "pill", hover = 12, press = 6 },
    })
    return self
end

function Launcher:launch()
    window_manager:toggle_window("Launcher")
end

function Launcher:widget()
    return self.button
end

return Launcher
