local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils

local Button = require("modules.m3components").Button

local ExoNotification = {}
ExoNotification.__index = ExoNotification

--- Human-readable age of a notification timestamp.
---@param timestamp number epoch seconds
---@return string
local function relative_time(timestamp)
    local diff = math.floor(os.time() - timestamp)
    if diff < 60 then
        return "now"
    elseif diff < 3600 then
        return tostring(math.floor(diff / 60)) .. "m"
    elseif diff < 86400 then
        return tostring(math.floor(diff / 3600)) .. "h"
    end
    return tostring(math.floor(diff / 86400)) .. "d"
end

---@param notification table Ignis Notification
---@param compact_popup? boolean
---@return table
function ExoNotification.new(notification, compact_popup)
    compact_popup = compact_popup or false

    local self = setmetatable({
        _timestamp = notification.time,
        _is_expanded = false,
        notification = notification,
    }, ExoNotification)

    self._age_label = widgets.Label({
        css_classes = { "notification-age" },
        label = "",
        halign = "start",
        ellipsize = "end",
        visible = not compact_popup,
    })

    self._body_label = nil
    if notification.body and notification.body ~= "" then
        self._body_label = widgets.Label({
            css_classes = { "notification-body" },
            label = notification.body,
            halign = "start",
            ellipsize = "end",
            wrap_mode = "word_char",
        })
        if compact_popup then
            self._body_label:set_single_line_mode(true)
        end
    end

    self._expand_button = nil
    if self._body_label and not compact_popup then
        self._expand_button = Button.button({
            css_classes = { "notification-expand" },
            icon = "arrow_drop_down",
            valign = "start",
            vexpand = false,
            size = "xs",
            on_click = function()
                self:_toggle_expand()
            end,
        })
    end

    local summary_children = {
        widgets.Label({
            css_classes = { "notification-summary" },
            label = notification.summary,
            halign = "start",
            ellipsize = "end",
        }),
        widgets.Label({
            css_classes = { "notification-separator" },
            label = "•",
            halign = "start",
            visible = not compact_popup,
        }),
        self._age_label,
    }

    local info_children = {
        widgets.Box({ spacing = 5, child = summary_children }),
    }
    if self._body_label then
        info_children[#info_children + 1] = self._body_label
    end
    if notification.actions and #notification.actions > 0 and not compact_popup then
        local action_buttons = {}
        for _, action in ipairs(notification.actions) do
            action_buttons[#action_buttons + 1] = Button.button({
                label = action.label,
                on_click = function()
                    action:invoke()
                end,
                css_classes = { "notification-action" },
                size = "xs",
                type = "text",
            })
        end
        info_children[#info_children + 1] = widgets.Box({
            css_classes = { "notification-actions-container" },
            child = action_buttons,
        })
    end

    local right_children = {
        Button.button({
            css_classes = { "notification-close" },
            icon = "close",
            valign = compact_popup and "center" or "start",
            vexpand = compact_popup,
            size = "xs",
            on_click = function()
                notification:close()
            end,
        }),
    }
    if self._expand_button and not compact_popup then
        right_children[#right_children + 1] = self._expand_button
    end

    local row_children = {
        widgets.Icon({
            image = (notification.icon and notification.icon ~= "") and notification.icon
                or "dialog-information-symbolic",
            pixel_size = compact_popup and 16 or 24,
            halign = "start",
            valign = "start",
            css_classes = { "notification-icon" },
        }),
        widgets.Box({
            css_classes = { "notification-info" },
            vertical = not compact_popup,
            valign = "center",
            hexpand = true,
            halign = "fill",
            spacing = compact_popup and 8 or 2,
            child = info_children,
        }),
        widgets.Box({
            vertical = true,
            spacing = 5,
            child = right_children,
        }),
    }

    local classes = { "notification" }
    if compact_popup then
        classes[#classes + 1] = "compact-popup"
    end

    self.box = widgets.Box({
        vertical = true,
        hexpand = true,
        halign = "fill",
        css_classes = classes,
        child = {
            widgets.Box({ spacing = 10, child = row_children }),
        },
    })

    self:_update_age_label()

    self._poll = utils.Poll({
        timeout = 60000,
        callback = function()
            self:_on_poll()
        end,
    })

    return self
end

function ExoNotification:_toggle_expand()
    self._is_expanded = not self._is_expanded
    if self._body_label then
        self._body_label:set_ellipsize(self._is_expanded and "none" or "end")
        self._body_label:set_wrap(self._is_expanded)
    end
    if self._expand_button then
        Button.set_icon(self._expand_button, self._is_expanded and "arrow_drop_up" or "arrow_drop_down")
    end
end

function ExoNotification:_on_poll()
    self:_update_age_label()
    if os.time() - self._timestamp >= 86400 and self._poll then
        self._poll:cancel()
    end
end

function ExoNotification:_update_age_label()
    self._age_label:set_label(relative_time(self._timestamp))
end

function ExoNotification:widget()
    return self.box
end

return ExoNotification
