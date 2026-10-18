local ignis = require("ignis")
local widgets = ignis.widgets

local user_settings = require("user_settings")
local AppIcon = require("modules.shared_modules.app_icon")
local compositor = require("modules.compositor")

local WindowInfo = {}
WindowInfo.__index = WindowInfo

local function bar_for(bar_id)
    if bar_id == 0 then
        return user_settings.interface.bar
    end
    return user_settings.interface.bar2
end

function WindowInfo.new()
    local self = setmetatable({}, WindowInfo)

    self.icon = AppIcon.new({ pixel_size = 16 })
    self.title_label = widgets.Label({
        css_classes = { "title" },
        halign = "start",
        ellipsize = "end",
        max_width_chars = 44,
        hexpand = true,
    })
    self.appid_label = widgets.Label({
        css_classes = { "app_id", "monospace-num" },
        halign = "start",
        ellipsize = "end",
        hexpand = true,
    })
    self.state_badge = widgets.Label({
        label = "FLT",
        valign = "center",
        visible = false,
        css_classes = { "window-state-badge", "monospace-num" },
    })

    self.title = nil
    self.app_id = nil

    self.label_box = widgets.Box({
        vertical = true,
        valign = "center",
        hexpand = true,
        child = { self.title_label, self.appid_label },
    })

    self.main_box = widgets.Box({
        vertical = false,
        spacing = 8,
        vexpand = true,
        css_classes = { "winfo" },
        child = { self.icon:widget(), self.label_box, self.state_badge },
    })

    self:update_layout()

    if compositor.service then
        compositor.service:connect("notify::active_window", function()
            self:update()
        end)
        compositor.service:connect("notify::windows", function()
            self:update()
        end)
        self:update()
    end

    return self
end

function WindowInfo:update()
    local window = compositor.service and compositor.service.active_window or nil
    local raw_title = window and window.title or ""
    local raw_app = window and compositor.window_app_id(window) or ""
    local pid = compositor.window_pid(window)
    local is_float = compositor.window_is_floating(window)

    self.title = (raw_title ~= "") and raw_title or "Workspace Ready"
    self.app_id = (raw_app ~= "") and raw_app or "exo-shell"

    local short_app = self.app_id:match("([^%.]+)$") or self.app_id
    local meta_str = short_app
    if pid then
        meta_str = string.format("%s · pid:%d", short_app, pid)
    end

    self.title_label:set_label(self.title)
    self.appid_label:set_label(meta_str)

    if is_float then
        self.state_badge:set_label("FLT")
        self.state_badge:set_visible(true)
    else
        self.state_badge:set_visible(false)
    end

    self.icon:set_app_id(self.app_id)
    self.icon:set_name(self.title)
    self.icon:set_visible(true)

    self.main_box:set_tooltip_text(string.format(
        "Class: %s\nTitle: %s%s%s",
        self.app_id,
        self.title,
        pid and string.format("\nPID: %d", pid) or "",
        is_float and "\nMode: Floating" or "\nMode: Tiled"
    ))
end

function WindowInfo:update_layout()
    local bar = bar_for(user_settings.interface.modules.bar_id.window_info)
    local is_vertical = bar.vertical
    local is_centered = bar.centered

    if is_vertical then
        self.main_box:set_halign("fill")
        self.main_box:set_valign("fill")
        self.main_box:set_hexpand(true)
        self.main_box:set_width_request(-1)
        self.label_box:set_visible(false)
        self.state_badge:set_visible(false)
        self.icon:set_halign("center")
        self.icon:set_hexpand(true)
    else
        self.main_box:set_valign("fill")
        self.label_box:set_visible(true)
        self.icon:set_halign("start")
        self.icon:set_hexpand(false)

        if is_centered then
            self.main_box:set_halign("center")
            self.main_box:set_width_request(160)
            self.main_box:set_hexpand(false)
        else
            self.main_box:set_halign("start")
            self.main_box:set_width_request(-1)
            self.main_box:set_hexpand(true)
        end

        if bar.density == 0 then
            self.title_label:set_visible(true)
            self.appid_label:set_visible(true)
        else
            self.title_label:set_visible(true)
            self.appid_label:set_visible(false)
        end
    end
end

function WindowInfo:widget()
    return self.main_box
end

return WindowInfo
