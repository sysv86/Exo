local ignis = require("ignis")
local window_manager = ignis.WindowManager.get_default()

local user_settings = require("user_settings")
local Corners = require("modules.corners.corners")

local BarStyles = {
    bar_instances = {},
    _rounded_corners_row = nil,
}

--- Rebuilds the corner overlay windows.
local function rebuild_corners()
    Corners.destroy_all()
    local misc = user_settings.interface.misc
    if misc.screen_corners ~= "disabled" or misc.shell_corners then
        Corners.build()
    end
end

function BarStyles._get_bar_settings(bar_id)
    if bar_id == 1 then
        return user_settings.interface.bar2
    end
    return user_settings.interface.bar
end

function BarStyles.add_bar_instance(bar)
    BarStyles.bar_instances[#BarStyles.bar_instances + 1] = bar
end

function BarStyles.clear_bars()
    BarStyles.bar_instances = {}
end

function BarStyles.set_rounded_corners_row(row)
    BarStyles._rounded_corners_row = row
end

--- Applies the bar's CSS class set for the given bar id.
function BarStyles._apply_css(window, bar_id)
    if not window then return end
    bar_id = bar_id or 0

    local bar_settings = BarStyles._get_bar_settings(bar_id)
    local side = bar_settings.side
    local vertical = bar_settings.vertical
    local separation = bar_settings.separation
    local floating = bar_settings.floating
    local centered = bar_settings.centered
    local compact_mode = bar_settings.density
    local module_backgrounds = bar_settings.module_backgrounds
    local bar_background = bar_settings.bar_background

    local all_possible_classes = {
        "hug", "extrapadding", "round", "floating", "full", "separated",
        "compact", "compact-plus", "ultracompact", "vertical",
        "module-backgrounds", "bar-background",
        "top", "bottom", "left", "right", "horizontal",
    }
    for _, class in ipairs(all_possible_classes) do
        window:remove_css_class(class)
    end

    if floating then
        window:add_css_class("floating")
    else
        window:add_css_class("hug")
        if not centered then
            window:add_css_class("extrapadding")
        else
            window:add_css_class("round")
        end
    end

    if separation then
        window:add_css_class("separated")
    else
        window:add_css_class("full")
    end

    if compact_mode == 1 then
        window:add_css_class("compact")
    elseif compact_mode == 2 then
        window:add_css_class("compact-plus")
    elseif compact_mode == 3 then
        window:add_css_class("ultracompact")
    end

    if vertical then
        window:add_css_class("vertical")
    else
        window:add_css_class("horizontal")
    end

    if module_backgrounds then
        window:add_css_class("module-backgrounds")
    end
    if bar_background then
        window:add_css_class("bar-background")
    end

    window:add_css_class(side)
end

function BarStyles._update_all_layouts()
    for _, bar in ipairs(BarStyles.bar_instances) do
        bar:update_layout()
        bar.clock:update_layout()
        bar.media:update_layout()
        bar.recording_indicator:update_layout()
        bar.recording_indicator:update_visibility()
        bar.systeminfotray:update_layout()
        bar.window_info:update_layout()
        bar.workspaces:update_layout()
        if bar.tasks and bar.tasks.update_layout then
            bar.tasks:update_layout()
        end
    end
end

function BarStyles._update_quick_center()
    local ok, quick_center = pcall(function()
        return window_manager:get_window("QuickCenter")
    end)
    if ok and quick_center and quick_center.update_side then
        quick_center:update_side()
    end
end

--- Layer-shell margins for a floating bar on the given side.
function BarStyles._compute_margins(side, bar_id)
    local bar_settings = BarStyles._get_bar_settings(bar_id)
    if not bar_settings.floating then
        return 0, 0, 0, 0
    end

    local top, left, right, bottom = 5, 5, 5, 5
    if side == "top" then
        bottom = 0
    elseif side == "bottom" then
        top = 0
    elseif side == "left" then
        right = 0
    elseif side == "right" then
        left = 0
    end
    return top, left, right, bottom
end

function BarStyles.setSide(side, bar_id)
    bar_id = bar_id or 0
    local bar_settings = BarStyles._get_bar_settings(bar_id)
    bar_settings.side = side
    bar_settings.vertical = (side == "left" or side == "right")

    for _, bar in ipairs(BarStyles.bar_instances) do
        local win = bar:get_window(bar_id)
        if win then
            local top, left, right, bottom = BarStyles._compute_margins(side, bar_id)
            win.margin_top = top
            win.margin_left = left
            win.margin_right = right
            win.margin_bottom = bottom

            local width, height = 40, 40
            local compact_mode = bar_settings.density
            if compact_mode == 1 then
                width, height = 35, 35
            elseif compact_mode == 2 then
                width, height = 30, 30
            elseif compact_mode == 3 then
                width, height = 25, 25
            end

            local vertical = bar_settings.vertical
            win:set_width_request(vertical and width or -1)
            win:set_height_request((not vertical) and height or -1)

            local centered = bar_settings.centered
            local anchors
            if centered then
                anchors = { side }
            elseif vertical then
                anchors = { "top", "bottom", side }
            else
                anchors = { "left", "right", side }
            end
            win.anchor = nil
            win.anchor = anchors

            local center_box = win.child
            local start_box = center_box:get_start_widget()
            local center_box_inner = center_box:get_center_widget()
            local end_box = center_box:get_end_widget()

            center_box.vertical = vertical
            center_box.halign = "fill"
            center_box.valign = "fill"

            if start_box then start_box.vertical = vertical end
            if center_box_inner then center_box_inner.vertical = vertical end
            if end_box then end_box.vertical = vertical end

            if vertical then
                if start_box then
                    start_box.halign = "fill"
                    start_box.valign = "start"
                    start_box.hexpand = true
                    start_box.vexpand = false
                end
                if center_box_inner then
                    center_box_inner.halign = "fill"
                    center_box_inner.valign = "center"
                    center_box_inner.hexpand = true
                    center_box_inner.vexpand = true
                end
                if end_box then
                    end_box.halign = "fill"
                    end_box.valign = "end"
                    end_box.hexpand = true
                    end_box.vexpand = false
                end
            else
                if start_box then
                    start_box.halign = "start"
                    start_box.valign = "fill"
                    start_box.hexpand = false
                    start_box.vexpand = true
                end
                if center_box_inner then
                    center_box_inner.halign = "center"
                    center_box_inner.valign = "fill"
                    center_box_inner.hexpand = true
                    center_box_inner.vexpand = false
                end
                if end_box then
                    end_box.halign = "end"
                    end_box.valign = "fill"
                    end_box.hexpand = false
                    end_box.vexpand = true
                end
            end

            BarStyles._apply_css(win, bar_id)
        end
    end

    BarStyles._update_all_layouts()
    rebuild_corners()
    BarStyles._update_quick_center()
end

function BarStyles.setCompact(mode, bar_id)
    bar_id = bar_id or 0
    local bar_settings = BarStyles._get_bar_settings(bar_id)
    bar_settings.density = mode

    for _, bar in ipairs(BarStyles.bar_instances) do
        local win = bar:get_window(bar_id)
        BarStyles._apply_css(win, bar_id)

        local width, height = 40, 40
        if mode == 1 then
            width, height = 35, 35
        elseif mode == 2 then
            width, height = 30, 30
        elseif mode == 3 then
            width, height = 25, 25
        end

        if win then
            if bar_settings.vertical then
                win:set_width_request(width)
            else
                win:set_height_request(height)
            end
        end
    end

    rebuild_corners()
    BarStyles._update_all_layouts()
end

function BarStyles.setRecordingIndicator(mode, bar_id)
    user_settings.interface.modules.options.recording_indicator = mode
    BarStyles._update_all_layouts()
end

function BarStyles.setWorkspacesStyle(style, bar_id)
    user_settings.interface.modules.options.workspaces_style = style
    for _, bar in ipairs(BarStyles.bar_instances) do
        if bar.workspaces then
            bar.workspaces:update_workspaces()
            bar.workspaces:update_layout()
        end
    end
end

function BarStyles.setSeparation(enabled, bar_id)
    BarStyles._get_bar_settings(bar_id or 0).separation = enabled
    for _, bar in ipairs(BarStyles.bar_instances) do
        BarStyles._apply_css(bar:get_window(bar_id or 0), bar_id or 0)
    end
end

function BarStyles.setBarBackground(enabled, bar_id)
    BarStyles._get_bar_settings(bar_id or 0).bar_background = enabled
    for _, bar in ipairs(BarStyles.bar_instances) do
        BarStyles._apply_css(bar:get_window(bar_id or 0), bar_id or 0)
    end
end

function BarStyles.setModuleBackgrounds(enabled, bar_id)
    BarStyles._get_bar_settings(bar_id or 0).module_backgrounds = enabled
    for _, bar in ipairs(BarStyles.bar_instances) do
        BarStyles._apply_css(bar:get_window(bar_id or 0), bar_id or 0)
    end
end

function BarStyles.setFloating(enabled, bar_id)
    bar_id = bar_id or 0
    local bar_settings = BarStyles._get_bar_settings(bar_id)
    bar_settings.floating = enabled

    for _, bar in ipairs(BarStyles.bar_instances) do
        BarStyles._apply_css(bar:get_window(bar_id), bar_id)
    end

    BarStyles.setSide(bar_settings.side, bar_id)
end

function BarStyles.setShellCorners(enabled)
    user_settings.interface.misc.shell_corners = enabled
    rebuild_corners()
end

function BarStyles.setBarCenter(enabled, bar_id)
    bar_id = bar_id or 0
    local bar_settings = BarStyles._get_bar_settings(bar_id)
    bar_settings.centered = enabled

    BarStyles.setSide(bar_settings.side, bar_id)
end

function BarStyles.setScreenCorners(enabled)
    user_settings.interface.misc.screen_corners = enabled
    rebuild_corners()
end

function BarStyles.setMilitaryTime(enabled)
    user_settings.interface.modules.options.military_time = enabled
    BarStyles._update_all_layouts()
end

function BarStyles.setDateVisibility(enabled)
    user_settings.interface.modules.options.show_date = enabled
    BarStyles._update_all_layouts()
end

function BarStyles.setDayMonthSwapped(enabled)
    user_settings.interface.modules.options.day_month_swapped = enabled
    BarStyles._update_all_layouts()
end

function BarStyles.setWidgetLocation(widget, location)
    user_settings.interface.modules.location[widget] = location
    BarStyles._update_all_layouts()
    BarStyles._update_quick_center()
end

function BarStyles.setWidgetVisibility(widget, visibility)
    user_settings.interface.modules.visibility[widget] = visibility
    BarStyles._update_all_layouts()
end

function BarStyles.setWidgetBarID(widget, bar_id)
    user_settings.interface.modules.bar_id[widget] = bar_id or 0
    BarStyles._update_all_layouts()
    BarStyles._update_quick_center()
end

return BarStyles
