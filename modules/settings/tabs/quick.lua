local ignis = require("ignis")
local widgets = ignis.widgets

local user_settings = require("user_settings")
local Wallpaper = require("scripts.wallpaper")
local BarStyles = require("scripts.set_bar_styles")
local settings_widgets = require("modules.settings.widgets")

local PALETTES = {
    "content",
    "expressive",
    "fidelity",
    "fruit-salad",
    "monochrome",
    "neutral",
    "rainbow",
    "tonal-spot",
}

local function basename(path)
    if not path or path == "" then return nil end
    return path:match("([^/]+)$")
end


local WallColorCategory = {}
WallColorCategory.__index = WallColorCategory

function WallColorCategory.new()
    local self = setmetatable({}, WallColorCategory)
    self.palettes = PALETTES
    self.palette_buttons = {}
    self.theme_buttons = {}

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            settings_widgets.CategoryLabel({ title = "Appearance", icon = "palette" }),
        },
    })

    self.wallpaper_picture = widgets.Picture({
        height = 300,
        width = 560,
        halign = "fill",
        hexpand = true,
        content_fit = "cover",
        css_classes = { "wallpaper-preview" },
    })
    self.wallpaper_picture.image = user_settings.appearance.wallcolors:bind("wallpaper_path")

    local initial_path = user_settings.appearance.wallcolors.wallpaper_path

    self.wallpaper_filename_label = widgets.Label({
        label = basename(initial_path) or "Click to set wallpaper",
        halign = "start",
        valign = "end",
        margin_start = 10,
        margin_bottom = 10,
        css_classes = { "wallpaper-filename-label" },
    })

    self.wallpaper_dialog = widgets.FileDialog({
        on_file_set = function(_, _, path)
            self:_set_and_update_wallpaper(path)
        end,
        initial_path = initial_path ~= "" and initial_path or nil,
    })

    local file_chooser_button = widgets.Button({
        css_classes = { "wallpaper-button-overlay" },
        on_click = function()
            self.wallpaper_dialog:show(nil)
        end,
    })

    local wallpaper_overlay = widgets.Overlay({
        css_classes = { "wallpaper-overlay" },
        child = self.wallpaper_picture,
        halign = "fill",
        hexpand = true,
    })

    wallpaper_overlay:add_overlay(file_chooser_button)
    wallpaper_overlay:add_overlay(self.wallpaper_filename_label)

    local palette_selector_row = widgets.Grid({
        column_spacing = 5,
        row_spacing = 5,
        css_classes = { "palette-selector-row" },
    })

    local function on_palette_selected(palette_name)
        Wallpaper.set_colors(palette_name)
        user_settings.appearance.wallcolors.color_scheme = palette_name
        self:_update_palette_selection()
    end

    local function make_palette_button(palette_name)
        local preview = widgets.Box({
            css_classes = { "preview", palette_name .. "-preview" },
            vertical = true,
            height_request = 50,
            width_request = 50,
            halign = "center",
            hexpand = false,
            valign = "center",
            vexpand = false,
            tooltip_text = palette_name,
            child = {
                widgets.Box({
                    css_classes = { "primary" },
                    height_request = 25,
                    width_request = 50,
                    hexpand = false,
                    halign = "start",
                }),
                widgets.Box({
                    vertical = false,
                    child = {
                        widgets.Box({
                            css_classes = { "secondary" },
                            height_request = 25,
                            width_request = 25,
                        }),
                        widgets.Box({
                            css_classes = { "tertiary" },
                            height_request = 25,
                            width_request = 25,
                        }),
                    },
                }),
            },
        })

        local btn = widgets.Button({
            on_click = function()
                on_palette_selected(palette_name)
            end,
            css_classes = { "palette-preview-btn" },
            hexpand = true,
            halign = "fill",
            child = preview,
        })
        btn.palette_name = palette_name
        preview.overflow = "hidden"
        return btn
    end

    for i, palette in ipairs(self.palettes) do
        local btn = make_palette_button(palette)
        self.palette_buttons[#self.palette_buttons + 1] = btn
        palette_selector_row:attach(btn, (i - 1) % 3, math.floor((i - 1) / 3), 1, 1)
    end

    local theme_selector_row = widgets.Box({
        vertical = false,
        spacing = 10,
        vexpand = true,
        valign = "fill",
        css_classes = { "theme-selector-row" },
    })

    local function on_theme_selected(is_dark)
        Wallpaper.set_dark_mode(is_dark)
        user_settings.appearance.wallcolors.dark_mode = is_dark
        self:_update_theme_selection()
    end

    local function make_theme_button(label, is_dark, css_class)
        local icon = is_dark and "dark_mode" or "light_mode"
        local btn = widgets.Button({
            on_click = function()
                on_theme_selected(is_dark)
            end,
            hexpand = true,
            halign = "fill",
            vexpand = true,
            valign = "fill",
            child = widgets.Box({
                vertical = true,
                css_classes = { css_class },
                hexpand = true,
                halign = "fill",
                vexpand = true,
                valign = "fill",
                child = {
                    widgets.Box({
                        vertical = true,
                        css_classes = { "container" },
                        hexpand = true,
                        halign = "fill",
                        vexpand = true,
                        valign = "fill",
                        spacing = 5,
                        child = {
                            widgets.Box({
                                css_classes = { "surface" },
                                width_request = 40,
                                vexpand = true,
                                valign = "fill",
                                child = {
                                    widgets.Box({
                                        halign = "center",
                                        hexpand = true,
                                        valign = "center",
                                        vexpand = true,
                                        spacing = 2,
                                        child = {
                                            widgets.Label({
                                                label = icon,
                                                css_classes = { "icon" },
                                            }),
                                            widgets.Label({ label = label }),
                                        },
                                    }),
                                },
                            }),
                            widgets.Box({
                                vertical = false,
                                spacing = 5,
                                child = {
                                    widgets.Box({
                                        css_classes = { "btn-1" },
                                        width_request = 30,
                                        hexpand = true,
                                        halign = "fill",
                                        height_request = 30,
                                    }),
                                    widgets.Box({
                                        css_classes = { "btn-2" },
                                        width_request = 30,
                                        height_request = 30,
                                    }),
                                    widgets.Box({
                                        css_classes = { "btn-3" },
                                        width_request = 30,
                                        height_request = 30,
                                    }),
                                },
                            }),
                        },
                    }),
                },
            }),
            css_classes = { "theme-preview-btn" },
        })
        btn.is_dark = is_dark
        btn.overflow = "hidden"
        return btn
    end

    local light_btn = make_theme_button("Light", false, "light-preview")
    local dark_btn = make_theme_button("Dark", true, "dark-preview")
    self.theme_buttons[#self.theme_buttons + 1] = light_btn
    self.theme_buttons[#self.theme_buttons + 1] = dark_btn
    theme_selector_row:append(light_btn)
    theme_selector_row:append(dark_btn)

    local right_column = widgets.Box({ vertical = true, spacing = 10 })
    right_column:append(theme_selector_row)
    right_column:append(palette_selector_row)

    local top_section = widgets.Box({
        vertical = false,
        spacing = 10,
        valign = "center",
        halign = "center",
    })
    top_section:append(wallpaper_overlay)
    top_section:append(right_column)

    self.box:append(top_section)

    self:_update_palette_selection()
    self:_update_theme_selection()

    return self
end

function WallColorCategory:_update_palette_selection()
    local selected_palette = user_settings.appearance.wallcolors.color_scheme
    for _, btn in ipairs(self.palette_buttons) do
        if btn.palette_name == selected_palette then
            btn:add_css_class("selected")
        else
            btn:remove_css_class("selected")
        end
    end
end

function WallColorCategory:_update_theme_selection()
    local selected_dark = user_settings.appearance.wallcolors.dark_mode
    for _, btn in ipairs(self.theme_buttons) do
        if btn.is_dark == selected_dark then
            btn:add_css_class("selected")
        else
            btn:remove_css_class("selected")
        end
    end
end

function WallColorCategory:_set_and_update_wallpaper(path)
    if path and path ~= "" then
        Wallpaper.set_wall(path)
        self.wallpaper_picture.image = path
        self.wallpaper_filename_label.label = basename(path) or path
    end
end

function WallColorCategory:widget()
    return self.box
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
    })

    self.box:append(settings_widgets.CategoryLabel({ title = "Bar", icon = "toolbar" }))

    self.box:append(settings_widgets.SettingsRow({
        title = "Position",
        description = "Pick a side for the bar to be located.",
        child = {
            settings_widgets.make_toggle_buttons({
                { "Top", "top", "align_vertical_top" },
                { "Bottom", "bottom", "align_vertical_bottom" },
                { "Left", "left", "align_horizontal_left" },
                { "Right", "right", "align_horizontal_right" },
            }, function()
                return bar.side
            end, BarStyles.setSide),
        },
    }))
    self.box:append(widgets.Separator())

    self.box:append(settings_widgets.SettingsRow({
        title = "Density",
        description = "Pick between 4 different density options.",
        child = {
            settings_widgets.make_toggle_buttons({
                { "Cozy", 0, "density_large" },
                { "Comfortable", 1, "density_medium" },
                { "Compact", 2, "density_small" },
                { "Condensed", 3, "list" },
            }, function()
                return bar.density
            end, BarStyles.setCompact),
        },
    }))
    self.box:append(widgets.Separator())

    self.box:append(settings_widgets.SettingsRow({
        title = "Extra Modifiers",
        description = "Add extra modifiers to the bar (You can select multiple).",
        child = {
            settings_widgets.make_independent_toggle_buttons({
                { "Floating", bar.get_floating, BarStyles.setFloating, "page_header" },
                { "Separated", bar.get_separation, BarStyles.setSeparation, "more_horiz" },
                { "Centered", bar.get_centered, BarStyles.setBarCenter, "code" },
            }),
        },
    }))
    self.box:append(widgets.Separator())

    self.box:append(settings_widgets.SettingsRow({
        title = "Backgrounds",
        description = "Add or remove the backgrounds of the Bar/Modules.",
        child = {
            settings_widgets.make_independent_toggle_buttons({
                { "Bar", bar.get_bar_background, BarStyles.setBarBackground, "toolbar" },
                { "Modules", bar.get_module_backgrounds, BarStyles.setModuleBackgrounds, "more_horiz" },
            }),
        },
    }))

    return self
end

function BarCategory:widget()
    return self.box
end


local MiscCategory = {}
MiscCategory.__index = MiscCategory

function MiscCategory.new()
    local self = setmetatable({}, MiscCategory)

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            settings_widgets.CategoryLabel({ title = "Miscellaneous", icon = "more_horiz" }),
            settings_widgets.SwitchRow(
                user_settings.interface.misc.shell_corners,
                function(_, active)
                    BarStyles.setShellCorners(active)
                end,
                {
                    title = "Rounded Shell Corners",
                    description = "Add a curve outside the shell that warps around the screen.",
                }
            ),
            widgets.Separator(),
            settings_widgets.SettingsRow({
                title = "Rounded Screen Corners",
                description = "Round the corners of the screen.",
                child = {
                    settings_widgets.make_toggle_buttons({
                        { "Disabled", "disabled", "close" },
                        { "When not fullscreen", "not_fullscreen", "fullscreen_exit" },
                        { "Always", "always", "check" },
                    }, function()
                        return user_settings.interface.misc.screen_corners
                    end, BarStyles.setScreenCorners),
                },
            }),
        },
    })

    return self
end

function MiscCategory:widget()
    return self.box
end


local QuickTab = {}
QuickTab.__index = QuickTab

function QuickTab.new()
    local self = setmetatable({}, QuickTab)

    self.box = widgets.Box({
        vertical = true,
        spacing = 8,
        css_classes = { "settings-body" },
        hexpand = false,
        halign = "center",
        width_request = 800,
    })

    self.box:append(WallColorCategory.new():widget())
    self.box:append(BarCategory.new():widget())
    self.box:append(MiscCategory.new():widget())

    return self
end

function QuickTab:widget()
    return self.box
end

return QuickTab
