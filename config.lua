local ignis = require("ignis")
local utils = ignis.utils
local CssManager = ignis.CssManager

local paths = require("paths")
local user_settings = require("user_settings")

package.loaded["exo.paths"] = paths
package.loaded["exo.user_settings"] = user_settings

local scripts = require("scripts")
local modules = require("modules")

package.loaded["exo.scripts"] = scripts
package.loaded["exo.modules"] = modules

local command_manager = ignis.CommandManager.get_default()
local css_manager = CssManager.get_default()
local window_manager = ignis.WindowManager.get_default()

scripts.Wallpaper.sync_colors()


css_manager.widgets_style_priority = "user"

local function sass_compiler(path)
    return utils.sass_compile({ path = path })
end

css_manager:apply_css(ignis.CssInfoPath({
    name = "main",
    path = paths.STYLES_DIR .. "/main.scss",
    compiler_function = sass_compiler,
    priority = "user",
}))

css_manager:apply_css(ignis.CssInfoPath({
    name = "colors",
    path = paths.COLORS_FILE,
    compiler_function = sass_compiler,
    priority = "user",
}))

if not user_settings.appearance.wallcolors.dark_mode then
    css_manager:apply_css(ignis.CssInfoPath({
        name = "lightthemeoverrides",
        path = paths.STYLES_DIR .. "/lightthemeoverrides.scss",
        compiler_function = sass_compiler,
        priority = "user",
    }))
end

utils.Timeout(50, function()
    scripts.Wallpaper.generate_previews()
end)


local quick_center = modules.QuickCenter.new()


for monitor = 0, utils.get_n_monitors() - 1 do
    local bar = modules.Bar.new(monitor)
    scripts.BarStyles.add_bar_instance(bar)
    scripts.BarStyles._apply_css(bar:build(), 0)
    scripts.BarStyles._apply_css(bar:build2(), 1)
end

scripts.BarStyles.setFloating(user_settings.interface.bar.floating, 0)
scripts.BarStyles.setFloating(user_settings.interface.bar2.floating, 1)


if not user_settings.appearance.wallcolors.wallpaper_path
    or user_settings.appearance.wallcolors.wallpaper_path == "" then
    local default_wallpaper = (os.getenv("HOME") or ".") .. "/Pictures/Wallpapers/default.png"
    if utils.file_exists(default_wallpaper) then
        print("[INFO] No wallpaper set in user_settings, setting default wallpaper.")
        scripts.Wallpaper.set_wall(default_wallpaper)
    else
        print("[INFO] No wallpaper set and default wallpaper file not found.")
    end
end


local misc = user_settings.interface.misc
if misc.screen_corners ~= "disabled" or misc.shell_corners then
    modules.Corners.build()
end

modules.Settings.new()
local launcher = modules.Launcher.new()
modules.PowerMenu.new()
modules.OSD.new()
modules.M3Test.new()

modules.NotificationPopup.new(0)

command_manager:add_command("toggle-launcher", function()
    if launcher and launcher.toggle_window then
        launcher:toggle_window()
    else
        window_manager:toggle_window("Launcher")
    end
end)

command_manager:add_command("toggle-quickcenter", function()
    if quick_center and quick_center.toggle_window then
        quick_center:toggle_window()
    else
        window_manager:toggle_window("QuickCenter")
    end
end)

command_manager:add_command("toggle-powermenu", function()
    window_manager:toggle_window("PowerMenu")
end)

command_manager:add_command("open-settings", function()
    window_manager:open_window("Settings")
end)

command_manager:add_command("open-m3-studio", function()
    window_manager:open_window("M3Test")
end)


utils.Poll(60000, function()
    scripts.auto_dark.auto_dark()
end)
