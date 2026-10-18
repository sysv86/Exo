local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local services = ignis.services

local Button = require("modules.m3components").Button
local ExoNotification = require("modules.notifications.notifications")

local notifications = services.NotificationService.get_default()


local Popup = {}
Popup.__index = Popup

function Popup.new(notification, props)
    props = props or {}
    local self = setmetatable({}, Popup)

    local widget = ExoNotification.new(notification)

    self.revealer = widgets.Revealer({
        child = widget:widget(),
        transition_type = "slide_down",
        transition_duration = 180,
        reveal_child = props.reveal_child,
        hexpand = props.hexpand,
        vexpand = props.vexpand,
        halign = props.halign,
    })

    notification:connect("closed", function()
        self:destroy()
    end)

    return self
end

function Popup:destroy()
    self.revealer.reveal_child = false
    utils.Timeout(self.revealer.transition_duration, function()
        self.revealer:unparent()
    end)
end

function Popup:widget()
    return self.revealer
end


local Notifications = {}
Notifications.__index = Notifications

function Notifications.new()
    local self = setmetatable({}, Notifications)

    self.loading_label = widgets.Label({
        label = "Loading notifications...",
        valign = "center",
        vexpand = true,
        css_classes = { "notification-center-info-label" },
    })

    self.box = widgets.Box({
        vertical = true,
        child = { self.loading_label },
        vexpand = true,
        css_classes = { "notification-center-content" },
        spacing = 4,
    })

    notifications:connect("notified", function(_, notification)
        self:_on_notified(notification)
    end)

    utils.ThreadTask({
        target = function()
            return self:_load_notifications()
        end,
        callback = function(result)
            self.box:set_child(result or {})
        end,
    }):run()

    return self
end

function Notifications:_on_notified(notification)
    local popup = Popup.new(notification)
    self.box:prepend(popup:widget())
    popup.revealer.reveal_child = true
end

function Notifications:_load_notifications()
    local contents = {}
    local list = notifications.notifications or {}
    for index = #list, 1, -1 do
        contents[#contents + 1] = Popup.new(list[index], { reveal_child = true }):widget()
    end

    local empty_binding = function()
        return notifications:bind("notifications", function(value)
            return #(value or {}) == 0
        end)
    end

    contents[#contents + 1] = widgets.Label({
        label = "notifications_off",
        valign = "end",
        vexpand = true,
        css_classes = { "notification-center-info-icon" },
        visible = empty_binding(),
    })
    contents[#contents + 1] = widgets.Label({
        label = "No notifications",
        valign = "start",
        vexpand = true,
        css_classes = { "notification-center-info-label" },
        visible = empty_binding(),
    })

    return contents
end

function Notifications:widget()
    return self.box
end


local NotificationCenter = {}
NotificationCenter.__index = NotificationCenter

function NotificationCenter.new()
    local self = setmetatable({}, NotificationCenter)

    self.list = Notifications.new()

    self.scroll = widgets.Scroll({
        child = self.list:widget(),
        vexpand = true,
        height_request = 210,
    })
    self.scroll:set_overflow("hidden")

    local header_row = widgets.Box({
        spacing = 8,
        valign = "center",
        css_classes = { "notification-center-header" },
        child = {
            widgets.Label({
                label = "Notifications",
                halign = "start",
                hexpand = true,
                css_classes = { "nc-title" },
            }),
            widgets.Label({
                label = notifications:bind("notifications", function(v)
                    return tostring(#(v or {}))
                end),
                css_classes = { "nc-count-badge" },
            }),
            Button.button({
                icon = "clear_all",
                label = "Clear",
                size = "xs",
                type = "tonal",
                visible = notifications:bind("notifications", function(v)
                    return #(v or {}) > 0
                end),
                on_click = function()
                    notifications:clear_all()
                end,
            }),
        },
    })

    self.box = widgets.Box({
        vertical = true,
        vexpand = true,
        css_classes = { "notification-center" },
        spacing = 8,
        child = { header_row, self.scroll },
    })

    return self
end

function NotificationCenter:widget()
    return self.box
end

setmetatable(NotificationCenter, {
    __call = function(cls, ...)
        return cls.new(...):widget()
    end,
})

return NotificationCenter
