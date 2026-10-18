local ignis = require("ignis")
local widgets = ignis.widgets

local user_settings = require("user_settings")
local recorder_script = require("scripts.recorder")

local widget_modules = require("modules.bar.widgets")

local Bar = {}
Bar.__index = Bar

---@param monitor number
function Bar.new(monitor)
    monitor = monitor or 0

    local self = setmetatable({
        monitor = monitor,
        _wins = {},
    }, Bar)

    self.media = widget_modules.Media.new()
    self.window_info = widget_modules.WindowInfo.new()
    self.workspaces = widget_modules.Workspaces.new()
    self.recording_indicator = widget_modules.RecordingIndicator.new()
    self.systeminfotray = widget_modules.SystemInfoTray.new()
    self.clock = widget_modules.Clock.new()
    self.tasks = widget_modules.Tasks.new()
    self.launcher = widget_modules.Launcher.new()

    recorder_script.set_indicator(self.recording_indicator)

    self.left_widgets = nil
    self.center_widgets = nil
    self.right_widgets = nil
    self.left_widgets2 = nil
    self.center_widgets2 = nil
    self.right_widgets2 = nil

    return self
end

--- Builds the primary bar window for this monitor.
function Bar:build()
    local bar = user_settings.interface.bar
    local side = bar.side
    local vertical = bar.vertical
    local compact_mode = bar.density

    local height, width = 40, 40
    if compact_mode == 1 then
        height, width = 35, 35
    elseif compact_mode == 2 then
        height, width = 30, 30
    elseif compact_mode == 3 then
        height, width = 25, 25
    end

    local anchors
    if bar.centered then
        anchors = { side }
    elseif vertical then
        anchors = { "top", "bottom", side }
    else
        anchors = { "left", "right", side }
    end

    self.left_widgets = widgets.Box({ vertical = vertical, spacing = 2, css_classes = { "left-widgets" } })
    self.center_widgets = widgets.Box({ vertical = vertical, spacing = 2, css_classes = { "center-widgets" } })
    self.right_widgets = widgets.Box({ vertical = vertical, spacing = 2, css_classes = { "right-widgets" } })

    local win_props = {
        namespace = "Bar" .. tostring(self.monitor),
        monitor = self.monitor,
        anchor = anchors,
        css_classes = { "bar" },
        exclusivity = "exclusive",
        child = widgets.CenterBox({
            vertical = vertical,
            css_classes = { "bar-widgets" },
            start_widget = self.left_widgets,
            center_widget = self.center_widgets,
            end_widget = self.right_widgets,
        }),
    }
    if vertical then
        win_props.width_request = width
    else
        win_props.height_request = height
    end

    self._wins[0] = widgets.Window(win_props)
    return self._wins[0]
end

--- Builds the secondary bar (dock) window for this monitor.
function Bar:build2()
    local bar = user_settings.interface.bar2
    local side = bar.side
    local vertical = bar.vertical
    local compact_mode = bar.density

    local height, width = 40, 40
    if compact_mode == 1 then
        height, width = 35, 35
    elseif compact_mode == 2 then
        height, width = 30, 30
    elseif compact_mode == 3 then
        height, width = 25, 25
    end

    local anchors
    if bar.centered then
        anchors = { side }
    elseif vertical then
        anchors = { "top", "bottom", side }
    else
        anchors = { "left", "right", side }
    end

    self.left_widgets2 = widgets.Box({ vertical = vertical, spacing = 2, css_classes = { "left-widgets" } })
    self.center_widgets2 = widgets.Box({ vertical = vertical, spacing = 2, css_classes = { "center-widgets" } })
    self.right_widgets2 = widgets.Box({ vertical = vertical, spacing = 2, css_classes = { "right-widgets" } })

    local win_props = {
        namespace = "Bar2" .. tostring(self.monitor),
        monitor = self.monitor,
        anchor = anchors,
        css_classes = { "bar" },
        exclusivity = "exclusive",
        visible = false,
        child = widgets.CenterBox({
            vertical = vertical,
            css_classes = { "bar-widgets" },
            start_widget = self.left_widgets2,
            center_widget = self.center_widgets2,
            end_widget = self.right_widgets2,
        }),
    }
    if vertical then
        win_props.width_request = width
    else
        win_props.height_request = height
    end

    self._wins[1] = widgets.Window(win_props)

    self:update_layout()
    return self._wins[1]
end

--- Re-distributes every widget into its configured area/bar.
function Bar:update_layout()
    for _, area in ipairs({
        self.left_widgets, self.center_widgets, self.right_widgets,
        self.left_widgets2, self.center_widgets2, self.right_widgets2,
    }) do
        if area then
            area:set_child({})
        end
    end

    local location_setting = user_settings.interface.modules.location
    local visibility_setting = user_settings.interface.modules.visibility
    local bar_id_setting = user_settings.interface.modules.bar_id

    local entries = {
        { name = "launcher", widget = self.launcher:widget() },
        { name = "window_info", widget = self.window_info:widget() },
        { name = "media", widget = self.media:widget() },
        { name = "workspaces", widget = self.workspaces:widget() },
        { name = "tasks", widget = self.tasks:widget() },
        { name = "recording_indicator", widget = self.recording_indicator:widget() },
        { name = "systeminfotray", widget = self.systeminfotray:widget() },
        { name = "clock", widget = self.clock:widget() },
    }

    local function area_for(location, bar_id)
        if bar_id == 0 then
            if location == 0 then return self.left_widgets end
            if location == 1 then return self.center_widgets end
            if location == 2 then return self.right_widgets end
        elseif bar_id == 1 then
            if location == 0 then return self.left_widgets2 end
            if location == 1 then return self.center_widgets2 end
            if location == 2 then return self.right_widgets2 end
        end
        return nil
    end

    local bar2_has_visible = false
    for _, entry in ipairs(entries) do
        local b_id = bar_id_setting[entry.name]
        local is_vis = visibility_setting[entry.name]
        local target = area_for(location_setting[entry.name], b_id)
        if target then
            target:append(entry.widget)
        end
        entry.widget:set_visible(is_vis)
        if b_id == 1 and is_vis then
            bar2_has_visible = true
        end
    end

    for _, area in ipairs({
        self.left_widgets, self.center_widgets, self.right_widgets,
        self.left_widgets2, self.center_widgets2, self.right_widgets2,
    }) do
        if area then
            local has_vis_child = false
            for _, ch in ipairs(area:get_child() or {}) do
                if ch.visible then
                    has_vis_child = true
                    break
                end
            end
            if not has_vis_child then
                area:add_css_class("empty")
            else
                area:remove_css_class("empty")
            end
        end
    end

    if not bar2_has_visible then
        user_settings.interface.bar2.enabled = false
        if self._wins[1] and self._wins[1].visible then
            self._wins[1]:set_visible(false)
        end
    else
        user_settings.interface.bar2.enabled = true
        if self._wins[1] and not self._wins[1].visible then
            self._wins[1]:set_visible(true)
        end
    end
end

---@param bar_id number
---@return table?
function Bar:get_window(bar_id)
    return self._wins[bar_id]
end

return Bar
