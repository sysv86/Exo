local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local services = ignis.services

local user_settings = require("user_settings")

local Battery = {}
Battery.__index = Battery

local function bar_for(bar_id)
    if bar_id == 0 then
        return user_settings.interface.bar
    end
    return user_settings.interface.bar2
end

function Battery.new()
    local self = setmetatable({
        upowerservice = services.UPowerService.get_default(),
        battery = nil,
        connected_signals = false,
    }, Battery)

    self.battery_percent = widgets.Label({ css_classes = { "battery-percent-label" } })
    self.battery_status = widgets.Label({ css_classes = { "battery-status" } })
    self.battery_fill = widgets.Box({ css_classes = { "battery-fill" } })

    self.text_container = widgets.Box({
        spacing = 2,
        halign = "center",
        valign = "center",
        homogeneous = false,
    })
    self.text_container:append(self.battery_status)
    self.text_container:append(self.battery_percent)

    self.battery_box = widgets.Overlay({
        child = self.battery_fill,
        overlays = { self.text_container },
        css_classes = { "battery-box" },
        halign = "center",
        valign = "center",
    })
    self.battery_box:set_overflow("hidden")

    self.container = widgets.Box({ spacing = 5, css_classes = { "battery-widget" } })
    self.container:append(self.battery_box)
    self.container:set_visible(false)

    self.upowerservice:connect("notify::batteries", function()
        self:_on_batteries_changed()
    end)

    utils.Timeout(100, function()
        self:_on_batteries_changed()
    end)
    self:update_layout()

    return self
end

function Battery:_on_batteries_changed()
    local batteries = self.upowerservice.batteries or {}
    if #batteries > 0 then
        self.battery = batteries[1]
        if not self.connected_signals then
            self.battery:connect("notify::percentage", function()
                self:_update_ui()
            end)
            self.battery:connect("notify::charging", function()
                self:_update_ui()
            end)
            self.battery:connect("notify::icon_name", function()
                self:_update_ui()
            end)
            self.connected_signals = true
        end
        self:_update_ui()
    else
        self.battery = nil
        self.connected_signals = false
        self:_update_ui()
    end
end

function Battery:update_layout()
    local bar = bar_for(user_settings.interface.modules.bar_id.systeminfotray)
    local is_vertical = bar.vertical
    self.container:set_vertical(is_vertical)
    self.text_container:set_vertical(is_vertical)

    if is_vertical then
        self.container:set_halign("fill")
        self.container:set_valign("center")
        self.container:set_hexpand(false)
        self.container:set_vexpand(false)
        self.battery_status:set_halign("center")
        self.battery_status:set_valign("end")
        self.battery_percent:set_valign("start")
        self.battery_percent:set_halign("center")
        self.battery_box:set_size_request(26, 40)
    else
        self.container:set_halign("center")
        self.container:set_valign("center")
        self.container:set_hexpand(false)
        self.container:set_vexpand(false)
        self.battery_status:set_halign("end")
        self.battery_status:set_valign("center")
        self.battery_percent:set_valign("center")
        self.battery_percent:set_halign("center")
        self.battery_box:set_size_request(50, 26)
    end

    self:_update_ui()
end

function Battery:_update_ui()
    if not (self.battery and self.battery.available) then
        self.container:set_visible(false)
        return
    end

    local percentage = math.floor(self.battery.percentage or 0)

    local status
    if self.battery.charging then
        status = "bolt"
    elseif percentage == 100 then
        status = "battery_android_full"
    elseif percentage >= 96 then
        status = "battery_android_6"
    elseif percentage >= 81 then
        status = "battery_android_5"
    elseif percentage >= 61 then
        status = "battery_android_4"
    elseif percentage >= 41 then
        status = "battery_android_3"
    elseif percentage >= 26 then
        status = "battery_android_2"
    elseif percentage >= 11 then
        status = "battery_android_1"
    elseif percentage >= 0 then
        status = "battery_android_0"
    else
        status = "battery_android_question"
    end

    local format_string
    if bar_for(user_settings.interface.modules.bar_id.systeminfotray).vertical then
        format_string = tostring(percentage)
        self.battery_fill:set_vexpand(true)
        self.battery_fill:set_valign("end")
        self.battery_fill:set_height_request(math.floor(40 * percentage / 100))
        self.battery_fill:set_width_request(26)
    else
        format_string = tostring(percentage) .. "%"
        self.battery_fill:set_hexpand(true)
        self.battery_fill:set_halign("start")
        self.battery_fill:set_height_request(26)
        self.battery_fill:set_width_request(math.floor(50 * percentage / 100))
    end

    self.battery_percent:set_label(format_string)
    self.battery_status:set_label(status)
    self.container:set_visible(true)

    if self.battery.charging then
        self.container:add_css_class("charging")
    else
        self.container:remove_css_class("charging")
    end

    if percentage <= 20 then
        self.container:add_css_class("low")
    else
        self.container:remove_css_class("low")
    end
end

function Battery:widget()
    return self.container
end

return Battery
