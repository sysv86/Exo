local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local m3 = require("modules.m3components")
local services = ignis.services
local window_manager = ignis.WindowManager.get_default()

local QuickSliders = {}
QuickSliders.__index = QuickSliders

function QuickSliders.new()
    local self = setmetatable({
        _updating_volume = false,
        _updating_mic = false,
        _updating_backlight = false,
    }, QuickSliders)

    self.audio = services.AudioService.get_default()
    self.backlight = services.BacklightService.get_default()

    local children = {}

    if self.audio.speaker then
        self.vol_icon_label = widgets.Label({ label = "volume_up", css_classes = { "m3-button-icon" } })
        self.vol_icon_btn = widgets.Button({
            css_classes = { "m3-button", "tonal", "xs", "icon-only" },
            tooltip_text = "Mute / Unmute Speaker",
            on_click = function()
                self.audio.speaker:toggle_mute()
            end,
            child = self.vol_icon_label,
        })
        m3.enhance_button(self.vol_icon_btn)

        self.volume_slider = widgets.Scale({
            min = 0,
            max = 100,
            step = 1.0,
            hexpand = true,
            css_classes = { "m3-expressive-slider" },
            on_change = function(slider)
                self:on_volume_changed(slider)
            end,
        })

        self.vol_badge = widgets.Label({
            label = "50%",
            halign = "end",
            css_classes = { "qs-slider-badge", "monospace-num" },
        })

        children[#children + 1] = widgets.Box({
            spacing = 10,
            valign = "center",
            css_classes = { "qs-slider-row" },
            child = {
                self.vol_icon_btn,
                self.volume_slider,
                self.vol_badge,
            },
        })
    end

    if self.audio.microphone then
        self.mic_icon_label = widgets.Label({ label = "mic", css_classes = { "m3-button-icon" } })
        self.mic_icon_btn = widgets.Button({
            css_classes = { "m3-button", "tonal", "xs", "icon-only" },
            tooltip_text = "Mute / Unmute Microphone",
            on_click = function()
                self.audio.microphone:toggle_mute()
            end,
            child = self.mic_icon_label,
        })
        m3.enhance_button(self.mic_icon_btn)

        self.mic_slider = widgets.Scale({
            min = 0,
            max = 100,
            step = 1.0,
            hexpand = true,
            css_classes = { "m3-expressive-slider" },
            on_change = function(slider)
                self:on_mic_changed(slider)
            end,
        })

        self.mic_badge = widgets.Label({
            label = "50%",
            halign = "end",
            css_classes = { "qs-slider-badge", "monospace-num" },
        })

        children[#children + 1] = widgets.Box({
            spacing = 10,
            valign = "center",
            css_classes = { "qs-slider-row" },
            child = {
                self.mic_icon_btn,
                self.mic_slider,
                self.mic_badge,
            },
        })
    end

    if self.backlight.available then
        self.bri_icon_label = widgets.Label({ label = "brightness_6", css_classes = { "m3-button-icon" } })
        self.bri_icon_btn = widgets.Button({
            css_classes = { "m3-button", "tonal", "xs", "icon-only" },
            tooltip_text = "Cycle Brightness (25% / 50% / 75% / 100%)",
            on_click = function()
                local pct = self.backlight.percentage or 50
                local next_pct = (pct < 30 and 50) or (pct < 60 and 75) or (pct < 90 and 100) or 25
                self:set_suppress_osd_flag()
                self.backlight.percentage = next_pct
            end,
            child = self.bri_icon_label,
        })
        m3.enhance_button(self.bri_icon_btn)

        self.backlight_slider = widgets.Scale({
            min = 0,
            max = 100,
            step = 1.0,
            hexpand = true,
            css_classes = { "m3-expressive-slider" },
            on_change = function(slider)
                self:on_backlight_changed(slider)
            end,
        })

        self.bri_badge = widgets.Label({
            label = "100%",
            halign = "end",
            css_classes = { "qs-slider-badge", "monospace-num" },
        })

        children[#children + 1] = widgets.Box({
            spacing = 10,
            valign = "center",
            css_classes = { "qs-slider-row" },
            child = {
                self.bri_icon_btn,
                self.backlight_slider,
                self.bri_badge,
            },
        })
    end

    self.box = widgets.Box({
        css_classes = { "qs-sliders-island", "quick-sliders-container" },
        hexpand = true,
        halign = "fill",
        spacing = 6,
        vertical = true,
        child = children,
    })

    if self.audio.speaker then
        self.audio.speaker:connect("notify::volume", function()
            self:_on_volume_changed()
        end)
        self.audio.speaker:connect("notify::is_muted", function()
            self:_on_volume_changed()
        end)
        self:_on_volume_changed()
    end

    if self.audio.microphone then
        self.audio.microphone:connect("notify::volume", function()
            self:_on_mic_changed()
        end)
        self.audio.microphone:connect("notify::is_muted", function()
            self:_on_mic_changed()
        end)
        self:_on_mic_changed()
    end

    if self.backlight.available then
        self.backlight:connect("notify::brightness", function()
            self:_on_brightness_changed()
        end)
        self:_on_brightness_changed()
    end

    return self
end

function QuickSliders:_on_volume_changed()
    if not self.volume_slider then return end
    local speaker = self.audio.speaker
    local vol = math.floor((speaker.volume or 0) + 0.5)

    if speaker.is_muted then
        if self.vol_icon_label then self.vol_icon_label.label = "volume_off" end
        if self.vol_badge then self.vol_badge.label = "Mute" end
        if not self._updating_volume then
            self.volume_slider:set_value(0)
        end
    else
        if self.vol_icon_label then
            self.vol_icon_label.label = (vol < 33 and "volume_mute") or (vol < 67 and "volume_down") or "volume_up"
        end
        if self.vol_badge then self.vol_badge.label = tostring(vol) .. "%" end
        if not self._updating_volume then
            self.volume_slider:set_value(vol)
        end
    end
end

function QuickSliders:_on_mic_changed()
    if not self.mic_slider then return end
    local mic = self.audio.microphone
    local vol = math.floor((mic.volume or 0) + 0.5)

    if mic.is_muted then
        if self.mic_icon_label then self.mic_icon_label.label = "mic_off" end
        if self.mic_badge then self.mic_badge.label = "Mute" end
        if not self._updating_mic then
            self.mic_slider:set_value(0)
        end
    else
        if self.mic_icon_label then self.mic_icon_label.label = "mic" end
        if self.mic_badge then self.mic_badge.label = tostring(vol) .. "%" end
        if not self._updating_mic then
            self.mic_slider:set_value(vol)
        end
    end
end

function QuickSliders:_on_brightness_changed()
    if not self.backlight_slider then return end
    local max_brightness = self.backlight.max_brightness
    if max_brightness and max_brightness > 0 then
        local pct = math.floor(((self.backlight.brightness or 0) / max_brightness) * 100 + 0.5)
        if self.bri_badge then
            self.bri_badge.label = tostring(pct) .. "%"
        end
        if self.bri_icon_label then
            self.bri_icon_label.label = (pct < 35 and "brightness_low") or (pct < 70 and "brightness_medium") or "brightness_high"
        end
        if not self._updating_backlight then
            self.backlight_slider:set_value(pct)
        end
    end
end

function QuickSliders:on_volume_changed(slider)
    self._updating_volume = true
    self:set_suppress_osd_flag()
    local val = math.floor((slider:get_value() or 0) + 0.5)
    if self.audio.speaker.is_muted and val > 0 then
        self.audio.speaker.is_muted = false
    end
    self.audio.speaker.volume = val
    if self.vol_badge then
        self.vol_badge.label = tostring(val) .. "%"
    end
    utils.Timeout(120, function()
        self._updating_volume = false
    end)
end

function QuickSliders:on_mic_changed(slider)
    self._updating_mic = true
    local val = math.floor((slider:get_value() or 0) + 0.5)
    if self.audio.microphone.is_muted and val > 0 then
        self.audio.microphone.is_muted = false
    end
    self.audio.microphone.volume = val
    if self.mic_badge then
        self.mic_badge.label = tostring(val) .. "%"
    end
    utils.Timeout(120, function()
        self._updating_mic = false
    end)
end

function QuickSliders:on_backlight_changed(slider)
    self._updating_backlight = true
    self:set_suppress_osd_flag()
    local pct = math.floor((slider:get_value() or 0) + 0.5)
    local max_brightness = self.backlight.max_brightness or 100
    self.backlight.brightness = math.floor((pct / 100) * max_brightness)
    if self.bri_badge then
        self.bri_badge.label = tostring(pct) .. "%"
    end
    utils.Timeout(120, function()
        self._updating_backlight = false
    end)
end

function QuickSliders:set_suppress_osd_flag()
    window_manager.suppress_osd = true
    utils.Timeout(150, function()
        window_manager.suppress_osd = false
    end)
end

function QuickSliders:widget()
    return self.box
end

return QuickSliders
