local ignis = require("ignis")
local options = ignis.options_manager
local Group = options.Group

local settings_file = (os.getenv("XDG_CONFIG_HOME")
    or ((os.getenv("HOME") or ".") .. "/.config")) .. "/ignis-lua/user_settings.json"

local user_settings = options.OptionsManager({
    file = settings_file,
    schema = Group({
        appearance = Group({
            wallcolors = Group({
                quickselect_path = "",
                wallpaper_path = "",
                color_scheme = "expressive",
                dark_mode = true,
                auto_dark = Group({
                    enabled = false,
                    start_hour = 22,
                    start_min = 0,
                    end_hour = 6,
                    end_min = 0,
                }),
            }),
        }),

        interface = Group({
            modules = Group({
                location = Group({
                    launcher = 0,
                    window_info = 0,
                    media = 0,
                    workspaces = 1,
                    tasks = 1,
                    recording_indicator = 2,
                    systeminfotray = 2,
                    clock = 2,
                }),
                visibility = Group({
                    window_info = true,
                    media = true,
                    workspaces = true,
                    recording_indicator = true,
                    systeminfotray = true,
                    clock = true,
                    tasks = false,
                    launcher = true,
                }),
                bar_id = Group({
                    launcher = 0,
                    window_info = 0,
                    media = 0,
                    workspaces = 0,
                    tasks = 0,
                    recording_indicator = 0,
                    systeminfotray = 0,
                    clock = 0,
                }),
                options = Group({
                    show_date = true,
                    day_month_swapped = false,
                    military_time = true,
                    recording_indicator = "recording",
                    workspaces_style = "numbers",
                    fixed_workspaces_enabled = true,
                    fixed_workspaces_amount = 5,
                    show_telemetry = true,
                    show_kb_layout = true,
                }),
            }),

            bar = Group({
                side = "top",
                vertical = false,
                density = 0,
                floating = true,
                separation = false,
                centered = false,
                bar_background = true,
                module_backgrounds = true,
            }),

            bar2 = Group({
                enabled = false,
                side = "bottom",
                vertical = false,
                density = 0,
                floating = true,
                separation = false,
                centered = false,
                bar_background = true,
                module_backgrounds = true,
            }),

            notifications = Group({
                anchor = options.list({ "top", "right" }),
                compact_popup = false,
            }),

            launcher = Group({
                layout = "list",
            }),

            misc = Group({
                shell_corners = true,
                screen_corners = "not_fullscreen",
            }),
        }),

        services = Group({
            recorder = Group({
                start_notification = true,
                stop_notification = true,
                record_audio = true,
            }),
            osd = Group({
                anchor = options.list({ "bottom" }),
                vertical = false,
            }),
        }),
    }),
})

local dark_mode_proxy = setmetatable({}, {
    __index = function(_, k)
        if k == "value" then
            return user_settings.appearance.wallcolors.dark_mode
        elseif k == "set_value" then
            return function(_, val)
                local ok, wp = pcall(require, "scripts.wallpaper")
                if ok and wp and wp.set_dark_mode then
                    wp.set_dark_mode(val and true or false)
                else
                    user_settings.appearance.wallcolors.dark_mode = val and true or false
                end
            end
        elseif k == "bind" then
            return function(_, transform)
                return user_settings.appearance.wallcolors:bind("dark_mode", transform)
            end
        end
        return nil
    end,
    __newindex = function(_, k, v)
        if k == "value" then
            local ok, wp = pcall(require, "scripts.wallpaper")
            if ok and wp and wp.set_dark_mode then
                wp.set_dark_mode(v and true or false)
            else
                user_settings.appearance.wallcolors.dark_mode = v and true or false
            end
        end
    end,
})

rawset(user_settings.interface, "dark_mode", dark_mode_proxy)

return user_settings
