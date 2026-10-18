local ignis = require("ignis")
local widgets = ignis.widgets
local services = ignis.services
local window_manager = ignis.WindowManager.get_default()

local user_settings = require("user_settings")

local OSD = {}
OSD.__index = OSD

function OSD.new()
    local self = setmetatable({}, OSD)

    self.icon = widgets.Label({ label = "volume_up", css_classes = { "osd-icon", "m3-icon" } })
    self.progress = widgets.Scale({
        css_classes = { "osd-progress", "m3-expressive-slider" },
        draw_value = false,
        min = 0,
        max = 1,
        step = 0.01,
        sensitive = false,
    })
    self.value_label = widgets.Label({
        label = "50%",
        css_classes = { "osd-value-label" },
        halign = "center",
    })

    local main_box = widgets.Box({
        valign = "center",
        halign = "center",
        css_classes = { "panel-surface", "osd" },
        spacing = 12,
        child = { self.icon, self.progress, self.value_label },
    })

    local revealer = widgets.Revealer({
        child = main_box,
        transition_duration = 220,
        transition_type = "crossfade",
        halign = "center",
        valign = "center",
    })

    self.window = widgets.RevealerWindow({
        revealer = revealer,
        child = revealer,
        kb_mode = "none",
        namespace = "OSD",
        exclusivity = "normal",
        visible = false,
        layer = "overlay",
        margin_top = 24,
        margin_bottom = 24,
        margin_left = 24,
        margin_right = 24,
    })

    self.main_box = main_box
    self.revealer = revealer
    self.hide_task = nil

    self.audio = services.AudioService.get_default()
    self.backlight = services.BacklightService.get_default()

    if self.audio.speaker then
        self.audio.speaker:connect("notify::volume", function()
            self:_on_volume_changed()
        end)
        self.audio.speaker:connect("notify::is_muted", function()
            self:_on_volume_changed()
        end)
    end
    self.backlight:connect("notify::brightness", function()
        self:_on_brightness_changed()
    end)

    local osd_settings = user_settings.services.osd
    osd_settings:connect_option("anchor", function()
        self:update_layout()
    end)
    osd_settings:connect_option("vertical", function()
        self:update_layout()
    end)

    self:update_layout()

    return self
end

function OSD:_on_volume_changed()
    self:show_osd()
    local speaker = self.audio.speaker
    local vol = math.floor((speaker.volume or 0) + 0.5)
    if speaker.is_muted then
        self.icon:set_label("volume_off")
        self.progress:set_value(0)
        self.value_label:set_label("Mute")
    else
        self.icon:set_label((vol < 33 and "volume_mute") or (vol < 67 and "volume_down") or "volume_up")
        self.progress:set_value(math.min(1.0, vol / 100.0))
        self.value_label:set_label(tostring(vol) .. "%")
    end
end

function OSD:_on_brightness_changed()
    self:show_osd()
    local max_brightness = self.backlight.max_brightness
    if max_brightness and max_brightness > 0 then
        local ratio = (self.backlight.brightness or 0) / max_brightness
        local pct = math.floor(ratio * 100 + 0.5)
        self.icon:set_label((pct < 35 and "brightness_low") or (pct < 70 and "brightness_medium") or "brightness_high")
        self.progress:set_value(math.min(1.0, math.max(0.0, ratio)))
        self.value_label:set_label(tostring(pct) .. "%")
    else
        self.icon:set_label("brightness_medium")
        self.progress:set_value(0)
        self.value_label:set_label("0%")
    end
end

function OSD:show_osd()
    if window_manager.suppress_osd then
        return
    end

    self.window.visible = true

    if self.hide_task then
        self.hide_task:cancel()
    end
    self.hide_task = ignis.utils.Timeout(1800, function()
        self.window.visible = false
    end)
end

function OSD:update_layout()
    local settings = user_settings.services.osd

    self.window:set_anchor(nil)
    self.window:set_anchor(settings.anchor)

    local anchor_key = table.concat(settings.anchor, "_")
    local vertical
    if anchor_key == "top" or anchor_key == "bottom" then
        vertical = false
    elseif anchor_key == "left" or anchor_key == "right" then
        vertical = true
    else
        vertical = settings.vertical
    end

    self.main_box:set_vertical(vertical)
    self.progress:set_vertical(vertical)

    if vertical then
        self.window:add_css_class("vertical")
        self.progress:set_height_request(180)
        self.progress:set_width_request(24)
    else
        self.window:remove_css_class("vertical")
        self.progress:set_height_request(24)
        self.progress:set_width_request(180)
    end
end

return OSD
