local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils

local user_settings = require("user_settings")
local recorder_script = require("scripts.recorder")

local recorder = recorder_script.recorder

local RecordingIndicator = {}
RecordingIndicator.__index = RecordingIndicator

local function bar_for(bar_id)
    if bar_id == 0 then
        return user_settings.interface.bar
    end
    return user_settings.interface.bar2
end

function RecordingIndicator.new()
    local self = setmetatable({
        is_recording = false,
        is_paused = false,
        _start_time = 0,
    }, RecordingIndicator)

    self.container = widgets.Button({
        on_click = function()
            self:handle_click()
        end,
        on_right_click = function()
            self:handle_right_click()
        end,
        css_classes = { "recording-indicator" },
        tooltip_text = "Click to start/stop recording. \nRight click to pause/unpause.",
    })
    self.container:set_name("recording-indicator")

    self.icon = widgets.Label({ label = "screen_record", css_classes = { "recording-icon" } })
    self.timer_label_hms = widgets.Label({ label = "00:00" })
    self.timer_label_s = widgets.Label({ label = "" })

    self.timer_box = widgets.Box({ css_classes = { "timer-box" } })
    self.timer_box:append(self.timer_label_hms)
    self.timer_box:append(self.timer_label_s)

    self.content_box = widgets.Box({})
    self.content_box:append(self.icon)
    self.content_box:append(self.timer_box)

    self.container:set_child(self.content_box)

    self:update_layout()
    self:update_visibility()

    utils.Poll(1000, function()
        self:_update_timer()
    end)

    return self
end

function RecordingIndicator:_update_timer()
    if not self.is_recording or self.is_paused then
        return
    end

    local seconds = os.time() - self._start_time
    if seconds < 0 then seconds = 0 end
    local m = math.floor(seconds / 60)
    local s = seconds % 60

    local bar = bar_for(user_settings.interface.modules.bar_id.recording_indicator)
    if bar.vertical then
        self.timer_label_hms:set_label(string.format("%02d", m))
        self.timer_label_s:set_label(string.format("%02d", s))
    else
        self.timer_label_hms:set_label(string.format("%02d:%02d", m, s))
        self.timer_label_s:set_label("")
    end
end

function RecordingIndicator:handle_click()
    local mode = user_settings.interface.modules.options.recording_indicator

    if mode == "always" then
        if recorder.active then
            recorder_script.stop_recording()
        else
            recorder_script.record_screen()
        end
    elseif mode == "recording" then
        if recorder.active then
            recorder_script.stop_recording()
        end
    end
end

function RecordingIndicator:handle_right_click()
    local mode = user_settings.interface.modules.options.recording_indicator

    if mode == "always" then
        if recorder.active then
            recorder_script.stop_recording()
        else
            recorder_script.record_region()
        end
    elseif mode == "recording" then
        if recorder.active then
            recorder_script.stop_recording()
        end
    end
end

function RecordingIndicator:toggle_pause_recording()
    if self.is_paused then
        recorder_script.unpause_recording()
    else
        recorder_script.pause_recording()
    end
end

function RecordingIndicator:set_paused(is_paused)
    self.is_paused = is_paused
    if is_paused then
        self.icon:set_label("pause")
        self.container:add_css_class("paused")
    else
        self.icon:set_label("screen_record")
        self.container:remove_css_class("paused")
    end
end

function RecordingIndicator:update_layout()
    local bar = bar_for(user_settings.interface.modules.bar_id.recording_indicator)
    local is_vertical = bar.vertical

    self.content_box:set_vertical(is_vertical)
    self.content_box:set_halign("center")
    self.content_box:set_valign("center")
    self.content_box:set_spacing(8)

    self.timer_box:set_vertical(is_vertical)
    self.timer_box:set_spacing(0)

    if is_vertical then
        self.timer_label_s:set_visible(true)
        self.timer_label_s:set_halign("center")
        self.content_box:set_homogeneous(false)
    else
        self.timer_label_s:set_visible(false)
        self.content_box:set_homogeneous(false)
    end
end

function RecordingIndicator:update_visibility()
    local mode = user_settings.interface.modules.options.recording_indicator
    local enabled = user_settings.interface.modules.visibility.recording_indicator

    if not enabled then
        self.container:set_visible(false)
        self.timer_box:set_visible(false)
    elseif mode == "always" then
        self.container:set_visible(true)
        self.timer_box:set_visible(self.is_recording)
        self.icon:set_visible(true)
    elseif mode == "recording" then
        self.container:set_visible(self.is_recording)
        self.icon:set_visible(self.is_recording)
        self.timer_box:set_visible(self.is_recording)
    end
end

function RecordingIndicator:start_timer()
    if not self.is_recording then
        self.is_recording = true
        self._start_time = os.time()
        self:update_visibility()
        self.container:add_css_class("recording-active")
    end
end

function RecordingIndicator:stop_timer()
    if self.is_recording then
        self.is_recording = false
        self.is_paused = false
        self.container:remove_css_class("paused")
        self:update_visibility()
        self.container:remove_css_class("recording-active")
    end
end

function RecordingIndicator:widget()
    return self.container
end

return RecordingIndicator
