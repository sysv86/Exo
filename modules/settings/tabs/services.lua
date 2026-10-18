local ignis = require("ignis")
local widgets = ignis.widgets
local services = ignis.services

local user_settings = require("user_settings")
local Button = require("modules.m3components").Button
local BarStyles = require("scripts.set_bar_styles")
local send_notification = require("scripts.send_notification")
local settings_widgets = require("modules.settings.widgets")

local CategoryLabel = settings_widgets.CategoryLabel
local SettingsRow = settings_widgets.SettingsRow
local SwitchRow = settings_widgets.SwitchRow
local make_toggle_buttons = settings_widgets.make_toggle_buttons
local make_independent_toggle_buttons = settings_widgets.make_independent_toggle_buttons

local notifications = services.NotificationService.get_default()


local NotificationsCategory = {}
NotificationsCategory.__index = NotificationsCategory

function NotificationsCategory.new()
    local self = setmetatable({}, NotificationsCategory)

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Notifications", icon = "notifications" }),
            SwitchRow(notifications.dnd, function(_, active)
                notifications.dnd = active
            end, {
                title = "Do Not Disturb",
                description = "When enabled, will stop popups for new notifications.",
            }),
            widgets.Separator(),
            SettingsRow({
                title = "Popup Timeout",
                description = "How long (in seconds) should a notification popup stay on screen.",
                child = {
                    widgets.SpinButton({
                        min = 1,
                        max = 60,
                        step = 1,
                        value = notifications.popup_timeout / 1000,
                        on_change = function(_, value)
                            notifications.popup_timeout = value * 1000
                        end,
                    }),
                },
            }),
            widgets.Separator(),
            SettingsRow({
                title = "Max Popups",
                description = "How many popup notifications can be shown at once.",
                child = {
                    widgets.SpinButton({
                        min = 1,
                        max = 20,
                        step = 1,
                        value = notifications.max_popups_count,
                        on_change = function(_, value)
                            notifications.max_popups_count = value
                        end,
                    }),
                },
            }),
            widgets.Separator(),
            SettingsRow({
                title = "Popup Location",
                description = "Pick a location for your notification popups.",
                child = {
                    make_toggle_buttons({
                        { "", { "top", "left" }, "north_west" },
                        { "Top", { "top" }, "north" },
                        { "", { "top", "right" }, "north_east" },
                        { "", { "bottom", "left" }, "south_west" },
                        { "Bottom", { "bottom" }, "south" },
                        { "", { "bottom", "right" }, "south_east" },
                    }, function()
                        return user_settings.interface.notifications.anchor
                    end, user_settings.interface.notifications.set_anchor, nil),
                },
            }),
            widgets.Separator(),
            SwitchRow(user_settings.interface.notifications.compact_popup, function(_, active)
                user_settings.interface.notifications.set_compact_popup(active)
            end, {
                title = "Compact Pop-up",
                description = "Show a more compact pop-up for incoming notifications.",
            }),
            widgets.Separator(),
            SettingsRow({
                title = "Send a Test Notification",
                child = {
                    Button.button({
                        icon = "notifications_unread",
                        label = "Test Notification",
                        halign = "start",
                        size = "xs",
                        on_click = function()
                            send_notification("Test Notification", "This is a test notification!")
                        end,
                    }),
                },
            }),
        },
    })

    return self
end

function NotificationsCategory:widget()
    return self.box
end


local RecordingCategory = {}
RecordingCategory.__index = RecordingCategory

function RecordingCategory.new()
    local self = setmetatable({}, RecordingCategory)
    local recorder = user_settings.services.recorder
    self.recorder = recorder

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Recording", icon = "screen_record" }),
            SettingsRow({
                title = "Notifications",
                description = "When should the recorder send a notification.",
                child = {
                    make_independent_toggle_buttons({
                        { "Started", recorder.get_start_notification, recorder.set_start_notification, "play_arrow" },
                        { "Stopped", recorder.get_stop_notification, recorder.set_stop_notification, "stop" },
                    }),
                },
            }),
            widgets.Separator(),
            SwitchRow(recorder.record_audio, function(_, active)
                recorder.set_record_audio(active)
            end, {
                title = "Record Audio",
                description = "Record the systems audio when recording.",
            }),
            widgets.Separator(),
            SettingsRow({
                title = "Recording Indicator",
                description = "When to show the recording indicator in the bar.",
                child = {
                    make_toggle_buttons({
                        { "Always", "always", "visibility" },
                        { "When Recording", "recording", "screen_record" },
                    }, function()
                        return user_settings.interface.modules.options.recording_indicator
                    end, BarStyles.setRecordingIndicator, nil),
                },
            }),
        },
    })

    return self
end

function RecordingCategory:widget()
    return self.box
end


local OSDCategory = {}
OSDCategory.__index = OSDCategory

function OSDCategory.new()
    local self = setmetatable({}, OSDCategory)
    self.recorder = user_settings.services.recorder

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "OSD", icon = "toast" }),
            SettingsRow({
                title = "Popup Location",
                description = "Pick a location for your OSD popups.",
                child = {
                    make_toggle_buttons({
                        { "", { "top", "left" }, "north_west" },
                        { "Top", { "top" }, "north" },
                        { "", { "top", "right" }, "north_east" },
                        { "", { "left" }, "west" },
                        { "", { "right" }, "east" },
                        { "", { "bottom", "left" }, "south_west" },
                        { "Bottom", { "bottom" }, "south" },
                        { "", { "bottom", "right" }, "south_east" },
                    }, function()
                        return user_settings.services.osd.anchor
                    end, user_settings.services.osd.set_anchor, nil),
                },
            }),
            widgets.Separator(),
            SwitchRow(user_settings.services.osd.vertical, function(_, active)
                user_settings.services.osd.set_vertical(active)
            end, {
                title = "Vertical",
                description = "Use a vertical OSD. Only takes effect when located in corners.",
            }),
        },
    })

    return self
end

function OSDCategory:widget()
    return self.box
end


local ServicesTab = {}
ServicesTab.__index = ServicesTab

function ServicesTab.new()
    local self = setmetatable({}, ServicesTab)

    self.box = widgets.Box({
        vertical = true,
        spacing = 8,
        css_classes = { "settings-body" },
        hexpand = false,
        halign = "center",
        width_request = 800,
        child = {
            NotificationsCategory.new():widget(),
            RecordingCategory.new():widget(),
            OSDCategory.new():widget(),
        },
    })

    return self
end

function ServicesTab:widget()
    return self.box
end

return ServicesTab
