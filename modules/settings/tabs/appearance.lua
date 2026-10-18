local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local Gtk = ignis.Gtk

local user_settings = require("user_settings")
local Wallpaper = require("scripts.wallpaper")
local auto_dark = require("scripts.auto_dark")
local settings_widgets = require("modules.settings.widgets")

local Pango = ignis.gi.require("Pango", "1.0")

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

local function make_spin_button(min, max, step, value, on_change)
    return widgets.SpinButton({
        min = min,
        max = max,
        step = step,
        value = value,
        on_change = function(_, val)
            if on_change then
                on_change(val)
            end
        end,
    })
end


local WallpaperCategory = {}
WallpaperCategory.__index = WallpaperCategory

function WallpaperCategory.new()
    local self = setmetatable({}, WallpaperCategory)

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            settings_widgets.CategoryLabel({ title = "Wallpaper", icon = "image" }),
        },
    })

    self.wallpaper_picture = widgets.Picture({
        height = 300,
        width = 560,
        vexpand = false,
        hexpand = false,
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
    })

    wallpaper_overlay:add_overlay(file_chooser_button)
    wallpaper_overlay:add_overlay(self.wallpaper_filename_label)

    self.box:append(wallpaper_overlay)

    return self
end

function WallpaperCategory:_set_and_update_wallpaper(path)
    if path and path ~= "" then
        Wallpaper.set_wall(path)
        self.wallpaper_picture.image = path
        self.wallpaper_filename_label.label = basename(path) or path
    end
end

function WallpaperCategory:widget()
    return self.box
end


local ColorCategory = {}
ColorCategory.__index = ColorCategory

function ColorCategory.new()
    local self = setmetatable({}, ColorCategory)
    self.palettes = PALETTES
    self.palette_buttons = {}
    self.theme_buttons = {}

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            settings_widgets.CategoryLabel({ title = "Colors", icon = "palette" }),
        },
    })

    local palette_selector_row = widgets.Box({
        spacing = 2,
        vertical = false,
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

    for _, palette_name in ipairs(self.palettes) do
        local btn = make_palette_button(palette_name)
        self.palette_buttons[#self.palette_buttons + 1] = btn
        palette_selector_row:append(btn)
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
                height_request = 100,
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

    self.box:append(settings_widgets.SettingsRow({
        title = "Themes",
        description = "Set your theme.",
        vertical = true,
        child = { theme_selector_row },
        css_classes = { "colors-row" },
    }))
    self.box:append(widgets.Separator())
    self.box:append(settings_widgets.SwitchRow(
        user_settings.appearance.wallcolors.auto_dark.enabled,
        function(_, active)
            auto_dark.set_auto_dark(active)
        end,
        {
            title = "Auto Dark",
            description = "Automatically set the dark theme based on the time of day.",
        }
    ))
    self.box:append(widgets.Separator())
    self.box:append(settings_widgets.SettingsRow({
        title = "Start Time",
        description = "Time of day to enable dark mode when Auto Dark is enabled.",
        child = {
            make_spin_button(0, 24, 1,
                user_settings.appearance.wallcolors.auto_dark.start_hour,
                function(value)
                    user_settings.appearance.wallcolors.auto_dark.set_start_hour(math.floor(value))
                end),
            make_spin_button(0, 60, 1,
                user_settings.appearance.wallcolors.auto_dark.start_min,
                function(value)
                    user_settings.appearance.wallcolors.auto_dark.set_start_min(math.floor(value))
                end),
        },
    }))
    self.box:append(widgets.Separator())
    self.box:append(settings_widgets.SettingsRow({
        title = "End Time",
        description = "Time of day to disable dark mode when Auto Dark is enabled.",
        child = {
            make_spin_button(0, 24, 1,
                user_settings.appearance.wallcolors.auto_dark.end_hour,
                function(value)
                    user_settings.appearance.wallcolors.auto_dark.set_end_hour(math.floor(value))
                end),
            make_spin_button(0, 60, 1,
                user_settings.appearance.wallcolors.auto_dark.end_min,
                function(value)
                    user_settings.appearance.wallcolors.auto_dark.set_end_min(math.floor(value))
                end),
        },
    }))
    self.box:append(widgets.Separator())
    self.box:append(settings_widgets.SettingsRow({
        title = "Color Schemes",
        description = "Set your color scheme.",
        vertical = true,
        child = { palette_selector_row },
        css_classes = { "colors-row" },
    }))

    self:_update_palette_selection()
    self:_update_theme_selection()

    return self
end

function ColorCategory:_update_palette_selection()
    local selected_palette = tostring(user_settings.appearance.wallcolors.color_scheme or ""):gsub("_", "-")
    for _, btn in ipairs(self.palette_buttons) do
        if btn.palette_name == selected_palette then
            btn:add_css_class("selected")
        else
            btn:remove_css_class("selected")
        end
    end
end

function ColorCategory:_update_theme_selection()
    local selected_dark = user_settings.appearance.wallcolors.dark_mode
    for _, btn in ipairs(self.theme_buttons) do
        if btn.is_dark == selected_dark then
            btn:add_css_class("selected")
        else
            btn:remove_css_class("selected")
        end
    end
end

function ColorCategory:widget()
    return self.box
end


local QuickSelectCategory = {}
QuickSelectCategory.__index = QuickSelectCategory

local function shell_quote(value)
    return "'" .. (tostring(value):gsub("'", "'\\''")) .. "'"
end

function QuickSelectCategory.new(wallpaper_category_ref)
    local self = setmetatable({}, QuickSelectCategory)
    self.wallpaper_category_ref = wallpaper_category_ref
    self.thumbnail_overlays = {}
    self._load_token = 0

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            settings_widgets.CategoryLabel({ title = "Quick Select", icon = "image" }),
        },
    })

    local quick_select_container = widgets.Box({
        vertical = true,
        spacing = 5,
        vexpand = true,
        valign = "fill",
    })

    local initial_path = user_settings.appearance.wallcolors.quickselect_path
    self.folder_dialog = widgets.FileDialog({
        select_folder = true,
        initial_path = initial_path ~= "" and initial_path or nil,
        on_file_set = function(_, _, path)
            if path and path ~= "" then
                user_settings.appearance.wallcolors.quickselect_path = path
                self:_find_and_create_gallery_async()
            end
        end,
    })

    local folder_chooser_button = widgets.Button({
        label = "Select a Folder",
        css_classes = { "folder-chooser-button" },
        on_click = function()
            self.folder_dialog:show(nil)
        end,
    })
    quick_select_container:append(folder_chooser_button)

    self.gallery_content_container = widgets.Box({
        vertical = true,
        halign = "fill",
        hexpand = true,
        valign = "fill",
        vexpand = true,
        css_classes = { "wallpaper-gallery-container" },
    })
    quick_select_container:append(self.gallery_content_container)

    self.gallery_content_container:append(widgets.Label({ label = "Loading wallpapers..." }))

    self:_find_and_create_gallery_async()

    self.box:append(quick_select_container)

    return self
end

function QuickSelectCategory:_find_and_create_gallery_async()
    self._load_token = (self._load_token or 0) + 1
    local token = self._load_token

    local wallpaper_dir = user_settings.appearance.wallcolors.quickselect_path
    if not wallpaper_dir or wallpaper_dir == "" or not utils.is_dir(wallpaper_dir) then
        wallpaper_dir = utils.expand_path("~/Pictures/Wallpapers")
    end

    if not utils.is_dir(wallpaper_dir) then
        self:_replace_gallery_content(nil)
        return
    end

    local command = string.format(
        "find %s -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' \\) | sort",
        shell_quote(wallpaper_dir))

    utils.exec_sh_async(command, function(result)
        if token ~= self._load_token then return end

        local image_files = {}
        for line in (result and result.stdout or ""):gmatch("[^\r\n]+") do
            image_files[#image_files + 1] = line
        end

        if #image_files == 0 then
            self:_replace_gallery_content(nil)
            return
        end

        local gallery_grid = widgets.Grid({
            halign = "fill",
            hexpand = true,
            column_spacing = 5,
            row_spacing = 5,
        })
        local gallery_scroll = widgets.Scroll({
            width_request = 600,
            height_request = 300,
        })
        gallery_scroll:set_child(gallery_grid)

        local thumbnails = {}
        self:_replace_gallery_content(gallery_scroll, thumbnails)

        local columns = 4
        local current_path = user_settings.appearance.wallcolors.wallpaper_path
        local idx = 1

        local function attach_next()
            if token ~= self._load_token then return end
            if idx > #image_files then return end

            local file_path = image_files[idx]
            local cell_idx = idx
            idx = idx + 1

            local is_selected = (file_path == current_path)
            local thumbnail_classes = { "wallpaper-thumbnail-image" }
            local button_classes = { "wallpaper-thumbnail" }
            if is_selected then
                thumbnail_classes[#thumbnail_classes + 1] = "selected"
                button_classes[#button_classes + 1] = "selected"
            end

            local btn = widgets.Button({
                on_click = function()
                    self.wallpaper_category_ref:_set_and_update_wallpaper(file_path)
                    self:_update_selected_icons()
                end,
                child = widgets.Picture({
                    image = file_path,
                    content_fit = "cover",
                    height = 100,
                    width = 196,
                    hexpand = true,
                    halign = "fill",
                    css_classes = thumbnail_classes,
                }),
                hexpand = true,
                halign = "fill",
                css_classes = button_classes,
            })
            btn.wallpaper_path = file_path
            gallery_grid:attach(btn, (cell_idx - 1) % columns, math.floor((cell_idx - 1) / columns), 1, 1)
            thumbnails[#thumbnails + 1] = btn

            if idx <= #image_files then
                utils.Timeout(8, attach_next)
            end
        end

        attach_next()
    end)
end

function QuickSelectCategory:_update_selected_icons()
    local current_path = user_settings.appearance.wallcolors.wallpaper_path
    for _, btn in ipairs(self.thumbnail_overlays) do
        local child = btn:get_child()
        if btn.wallpaper_path == current_path then
            btn:add_css_class("selected")
            if child then child:add_css_class("selected") end
        else
            btn:remove_css_class("selected")
            if child then child:remove_css_class("selected") end
        end
    end
end

function QuickSelectCategory:_replace_gallery_content(new_child, thumbnail_buttons)
    while self.gallery_content_container:get_last_child() do
        self.gallery_content_container:remove(self.gallery_content_container:get_last_child())
    end

    if new_child then
        self.gallery_content_container:append(new_child)
        if thumbnail_buttons then
            self.thumbnail_overlays = thumbnail_buttons
        end
    else
        self.gallery_content_container:append(widgets.Label({
            label = "No wallpapers found in the directory.",
            css_classes = { "message" },
        }))
    end
end

function QuickSelectCategory:widget()
    return self.box
end


local FontCategory = {}
FontCategory.__index = FontCategory

function FontCategory.new()
    local self = setmetatable({}, FontCategory)

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
    })
    self.box:append(settings_widgets.CategoryLabel({ title = "Fonts", icon = "custom_typography" }))

    local font_dialog = Gtk.FontDialog.new()
    local font_button = widgets.FontDialogButton({ dialog = font_dialog })

    local gtk_settings = Gtk.Settings.get_default()
    local font_name = gtk_settings.gtk_font_name
    font_button:set_font_desc(Pango.FontDescription.from_string(font_name))

    self.box:append(settings_widgets.SettingsRow({
        title = "Font",
        description = "Select a system font.",
        child = { font_button },
    }))

    font_button:connect("notify::font-desc", function(button)
        self:_on_font_set(button)
    end)

    return self
end

function FontCategory:_on_font_set(button)
    local font_desc = button:get_font_desc()
    if not font_desc then
        return
    end

    local font_name = font_desc:to_string()

    local gtk_settings = Gtk.Settings.get_default()
    gtk_settings.gtk_font_name = font_name

    utils.exec_sh_async(string.format(
        "gsettings set org.gnome.desktop.interface font-name '%s'", font_name))
end

function FontCategory:widget()
    return self.box
end


local AppearanceTab = {}
AppearanceTab.__index = AppearanceTab

function AppearanceTab.new()
    local self = setmetatable({}, AppearanceTab)

    self.box = widgets.Box({
        vertical = true,
        spacing = 8,
        css_classes = { "settings-body" },
        hexpand = false,
        halign = "center",
        width_request = 800,
    })

    local wallpaper_category = WallpaperCategory.new()
    self.box:append(wallpaper_category:widget())
    self.box:append(ColorCategory.new():widget())
    self.box:append(FontCategory.new():widget())
    self.box:append(QuickSelectCategory.new(wallpaper_category):widget())

    return self
end

function AppearanceTab:widget()
    return self.box
end

return AppearanceTab
