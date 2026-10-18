local ignis = require("ignis")
local widgets = ignis.widgets

local user_settings = require("user_settings")
local BarStyles = require("scripts.set_bar_styles")
local settings_widgets = require("modules.settings.widgets")

local CategoryLabel = settings_widgets.CategoryLabel
local SettingsRow = settings_widgets.SettingsRow
local SwitchRow = settings_widgets.SwitchRow
local make_toggle_buttons = settings_widgets.make_toggle_buttons
local make_independent_toggle_buttons = settings_widgets.make_independent_toggle_buttons

local SIDE_ITEMS = {
    { "Top", "top", "align_vertical_top" },
    { "Bottom", "bottom", "align_vertical_bottom" },
    { "Left", "left", "align_horizontal_left" },
    { "Right", "right", "align_horizontal_right" },
}

local DENSITY_ITEMS = {
    { "Cozy", 0, "density_large" },
    { "Comfortable", 1, "density_medium" },
    { "Compact", 2, "density_small" },
    { "Condensed", 3, "list" },
}

local function position_row(bar, bar_id)
    return SettingsRow({
        title = "Position",
        description = "Pick a side for the bar to be located.",
        child = {
            make_toggle_buttons(
                SIDE_ITEMS,
                function() return bar.side end,
                BarStyles.setSide,
                nil,
                nil,
                bar_id
            ),
        },
    })
end

local function density_row(bar, bar_id)
    return SettingsRow({
        title = "Density",
        description = "Pick between 4 different density options.",
        child = {
            make_toggle_buttons(
                DENSITY_ITEMS,
                function() return bar.density end,
                BarStyles.setCompact,
                nil,
                nil,
                bar_id
            ),
        },
    })
end

local function extra_modifiers_row(bar, bar_id)
    return SettingsRow({
        title = "Extra Modifiers",
        description = "Add extra modifiers to the bar (You can select multiple).",
        child = {
            make_independent_toggle_buttons({
                { "Floating", bar.get_floating, BarStyles.setFloating, "page_header" },
                { "Separated", bar.get_separation, BarStyles.setSeparation, "more_horiz" },
                { "Centered", bar.get_centered, BarStyles.setBarCenter, "code" },
            }, nil, bar_id),
        },
    })
end

local function backgrounds_row(bar, bar_id)
    return SettingsRow({
        title = "Backgrounds",
        description = "Add or remove the backgrounds of the Bar/Modules.",
        child = {
            make_independent_toggle_buttons({
                { "Bar", bar.get_bar_background, BarStyles.setBarBackground, "toolbar" },
                { "Modules", bar.get_module_backgrounds, BarStyles.setModuleBackgrounds, "more_horiz" },
            }, nil, bar_id),
        },
    })
end

local BarCategory = {}
BarCategory.__index = BarCategory

function BarCategory.new()
    local self = setmetatable({}, BarCategory)
    local bar = user_settings.interface.bar

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Bar", icon = "toolbar" }),
            position_row(bar, nil),
            widgets.Separator(),
            density_row(bar, nil),
            widgets.Separator(),
            extra_modifiers_row(bar, nil),
            widgets.Separator(),
            backgrounds_row(bar, nil),
        },
    })

    return self
end

function BarCategory:widget()
    return self.box
end

local Bar2Category = {}
Bar2Category.__index = Bar2Category

function Bar2Category.new()
    local self = setmetatable({}, Bar2Category)
    local bar = user_settings.interface.bar2

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Second Bar", icon = "bottom_navigation" }),
            SettingsRow({
                description = "The second bar will be automatically enabled if any modules are located in it.\n"
                    .. "It will automatically be disabled if there are no modules located in it.\n"
                    .. "Note: If any disabled modules are located in the second bar, it will still be enabled.",
            }),
            widgets.Separator(),
            position_row(bar, 1),
            widgets.Separator(),
            density_row(bar, 1),
            widgets.Separator(),
            extra_modifiers_row(bar, 1),
            widgets.Separator(),
            backgrounds_row(bar, 1),
        },
    })

    return self
end

function Bar2Category:widget()
    return self.box
end

local function make_module_settings(name, widget_name, description)
    local bar_id_group = user_settings.interface.modules.bar_id
    local location_group = user_settings.interface.modules.location
    local visibility_group = user_settings.interface.modules.visibility

    local bar_id_buttons = make_toggle_buttons({
        { false, 0, "timer_1" },
        { false, 1, "timer_2" },
    }, function()
        return bar_id_group[widget_name]
    end, BarStyles.setWidgetBarID, nil, widget_name)

    local location_buttons = make_toggle_buttons({
        { "Start", 0 },
        { "Center", 1 },
        { "End", 2 },
    }, function()
        return location_group[widget_name]
    end, BarStyles.setWidgetLocation, nil, widget_name)

    local visibility_switch = widgets.Switch({
        vexpand = false,
        valign = "center",
        active = visibility_group[widget_name],
        on_change = function(_, active)
            BarStyles.setWidgetVisibility(widget_name, active)
        end,
    })

    return SettingsRow({
        title = name .. " Widget",
        description = description,
        css_classes = { "module-options" },
        child = {
            widgets.Box({ vertical = false, child = { bar_id_buttons } }),
            widgets.Separator(),
            widgets.Box({ vertical = false, child = { location_buttons } }),
            widgets.Separator(),
            visibility_switch,
        },
    })
end

local BAR_MODULES = {
    { name = "Launcher", widget = "launcher", description = "Button to open the Launcher." },
    { name = "Window Info", widget = "window_info", description = "Shows information about the active window." },
    { name = "Media", widget = "media", description = "Shows the currently playing media with controls." },
    { name = "Workspaces", widget = "workspaces", description = "Shows a list of workspaces." },
    { name = "Tasks", widget = "tasks", description = "Shows pinned and currently running applications." },
    { name = "Recording Indicator", widget = "recording_indicator", description = "Shows the current recording status." },
    { name = "System Tray", widget = "systeminfotray", description = "Shows system tray, C11 hardware telemetry, and XKB layout." },
    { name = "Clock", widget = "clock", description = "Shows the current time and date." },
}

local BarModulesCategory = {}
BarModulesCategory.__index = BarModulesCategory

function BarModulesCategory.new()
    local self = setmetatable({}, BarModulesCategory)

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Bar Modules", icon = "dashboard_2" }),
        },
    })

    for index, module in ipairs(BAR_MODULES) do
        self.box:append(make_module_settings(module.name, module.widget, module.description))
        if index ~= #BAR_MODULES then
            self.box:append(widgets.Separator())
        end
    end

    return self
end

function BarModulesCategory:widget()
    return self.box
end

local ExtraBarCategory = {}
ExtraBarCategory.__index = ExtraBarCategory

function ExtraBarCategory.new()
    local self = setmetatable({}, ExtraBarCategory)
    local options = user_settings.interface.modules.options

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Extra Module Options", icon = "settings" }),
            SettingsRow({
                title = "Workspace Indicator Style",
                description = "Pick between 3 different Workspace Indicator styles.",
                child = {
                    make_toggle_buttons({
                        { "Icons", "windows", "photo" },
                        { "Numbers", "numbers", "counter_1" },
                        { "Dots", "dots", "more_horiz" },
                    }, function()
                        return options.workspaces_style
                    end, BarStyles.setWorkspacesStyle, nil),
                },
            }),
            widgets.Separator(),
            SwitchRow(options.fixed_workspaces_enabled, function(_, active)
                options.set_fixed_workspaces_enabled(active)
            end, {
                title = "Fixed Workspaces",
                description = "Show a specific amount of workspaces",
            }),
            widgets.Separator(),
            SettingsRow({
                title = "Fixed Workspaces Amount",
                description = "How many workspaces to show.",
                child = {
                    widgets.SpinButton({
                        min = 1,
                        max = 20,
                        step = 1,
                        value = options.fixed_workspaces_amount,
                        on_change = function(_, value)
                            options.set_fixed_workspaces_amount(math.floor(tonumber(value) or 0))
                        end,
                    }),
                },
            }),
            widgets.Separator(),
            SwitchRow(options.show_telemetry ~= false, function(_, active)
                options.set_show_telemetry(active)
            end, {
                title = "Developer Hardware Telemetry",
                description = "Show live C11 zero-subprocess CPU % and RAM GiB metrics in the bar.",
            }),
            widgets.Separator(),
            SwitchRow(options.show_kb_layout ~= false, function(_, active)
                options.set_show_kb_layout(active)
            end, {
                title = "Keyboard Layout Switcher",
                description = "Show active XKB layout pill (EN / RU) in the bar.",
            }),
            widgets.Separator(),
            SwitchRow(options.military_time, function(_, active)
                BarStyles.setMilitaryTime(active)
            end, {
                title = "Use 24 hour time",
                description = "Toggle between 12-hour (AM/PM) and 24-hour time formats.",
            }),
            widgets.Separator(),
            SwitchRow(options.show_date, function(_, active)
                BarStyles.setDateVisibility(active)
            end, {
                title = "Show the date",
                description = "Toggle the visibility of the date in the bar.",
            }),
            widgets.Separator(),
            SwitchRow(options.day_month_swapped, function(_, active)
                BarStyles.setDayMonthSwapped(active)
            end, {
                title = "Swap the day and month",
                description = "Use the American date format.",
            }),
        },
    })

    return self
end

function ExtraBarCategory:widget()
    return self.box
end

local MiscCategory = {}
MiscCategory.__index = MiscCategory

function MiscCategory.new()
    local self = setmetatable({}, MiscCategory)
    local misc = user_settings.interface.misc

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Miscellaneous", icon = "more_horiz" }),
            SwitchRow(misc.shell_corners, function(_, active)
                BarStyles.setShellCorners(active)
            end, {
                title = "Rounded Shell Corners",
                description = "Add a curve outside the shell that warps around the screen.",
            }),
            widgets.Separator(),
            SettingsRow({
                title = "Rounded Screen Corners",
                description = "Round the corners of the screen.",
                child = {
                    make_toggle_buttons({
                        { "Disabled", "disabled", "close" },
                        { "When not fullscreen", "not_fullscreen", "fullscreen_exit" },
                        { "Always", "always", "check" },
                    }, function()
                        return user_settings.interface.misc.screen_corners
                    end, BarStyles.setScreenCorners, nil),
                },
            }),
        },
    })

    return self
end

function MiscCategory:widget()
    return self.box
end

local Tab = {}
Tab.__index = Tab

function Tab.new()
    local self = setmetatable({}, Tab)

    self.box = widgets.Box({
        vertical = true,
        spacing = 8,
        css_classes = { "settings-body" },
        hexpand = false,
        halign = "center",
        width_request = 800,
        child = {
            BarCategory.new():widget(),
            Bar2Category.new():widget(),
            BarModulesCategory.new():widget(),
            ExtraBarCategory.new():widget(),
            MiscCategory.new():widget(),
        },
    })

    self.box.hexpand = true
    self.box.vexpand = true

    return self
end

function Tab:widget()
    return self.box
end

return Tab
