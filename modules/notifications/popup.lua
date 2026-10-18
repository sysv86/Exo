local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local services = ignis.services

local user_settings = require("user_settings")
local ExoNotification = require("modules.notifications.notifications")

local notifications = services.NotificationService.get_default()


local Popup = {}
Popup.__index = Popup

---@param box table parent PopupBox
---@param window table parent NotificationPopup
---@param notification table
function Popup.new(box, window, notification)
    local self = setmetatable({ _box = box, _window = window }, Popup)

    local compact = user_settings.interface.notifications.compact_popup
    local widget = ExoNotification.new(notification, compact)

    local classes = { "notification-popup" }
    if compact then
        classes[#classes + 1] = "compact-popup"
    end
    widget:widget().css_classes = classes

    self._inner = widgets.Revealer({
        transition_type = "slide_down",
        child = widget:widget(),
        hexpand = true,
        halign = "fill",
    })
    self._outer = widgets.Revealer({
        transition_type = "slide_down",
        child = self._inner,
        hexpand = true,
        halign = "fill",
    })
    self.box = widgets.Box({
        child = { self._outer },
        halign = "fill",
        valign = "fill",
        hexpand = true,
    })

    notification:connect("dismissed", function()
        self:destroy()
    end)

    return self
end

function Popup:destroy()
    local function box_destroy()
        self.box:unparent()
        if #(notifications.popups or {}) == 0 then
            self._window.window.visible = false
        end
    end

    local function outer_close()
        self._outer.reveal_child = false
        utils.Timeout(self._outer.transition_duration, box_destroy)
    end

    self._inner.reveal_child = false
    utils.Timeout(self._outer.transition_duration, outer_close)
end

function Popup:widget()
    return self.box
end


local PopupBox = {}
PopupBox.__index = PopupBox

function PopupBox.new(window, monitor)
    local self = setmetatable({ _window = window, _monitor = monitor }, PopupBox)

    self.box = widgets.Box({
        vertical = true,
        valign = "start",
        spacing = 3,
    })

    notifications:connect("new-popup", function(_, notification)
        self:_on_notified(notification)
    end)

    return self
end

function PopupBox:_on_notified(notification)
    self._window:_update_window_properties()
    self._window.window.visible = true

    local popup = Popup.new(self, self._window, notification)
    if user_settings.interface.bar.side == "top" then
        self.box:prepend(popup:widget())
    else
        self.box:append(popup:widget())
    end

    popup._outer.reveal_child = true
    utils.Timeout(popup._outer.transition_duration, function()
        popup._inner:set_reveal_child(true)
    end)
end

function PopupBox:widget()
    return self.box
end


local NotificationPopup = {}
NotificationPopup.__index = NotificationPopup

function NotificationPopup.new(monitor)
    local self = setmetatable({}, NotificationPopup)

    self.popup_box = PopupBox.new(self, monitor)

    self.window = widgets.Window({
        anchor = user_settings.interface.notifications.anchor,
        monitor = monitor,
        namespace = "notification",
        layer = "overlay",
        child = self.popup_box:widget(),
        visible = false,
        dynamic_input_region = true,
        css_classes = { "notification-popup-container" },
    })

    self:_update_window_properties()
    return self
end

function NotificationPopup:_update_window_properties()
    self.window:set_anchor(nil)
    self.window:set_anchor(user_settings.interface.notifications.anchor)
end

return NotificationPopup
