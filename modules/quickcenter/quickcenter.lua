local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local services = ignis.services
local window_manager = ignis.WindowManager.get_default()
local css_manager = ignis.CssManager.get_default()

local user_settings = require("user_settings")
local Wallpaper = require("scripts.wallpaper")
local recorder_script = require("scripts.recorder")
local send_notification = require("scripts.send_notification")
local quick_widgets = require("modules.quickcenter.widgets")
local m3 = require("modules.m3components")

local network = services.NetworkService.get_default()
local bluetooth = services.BluetoothService.get_default()
local audio = services.AudioService.get_default()
local notifications = services.NotificationService.get_default()
local mpris = services.MprisService.get_default()
local power_profiles = services.PowerProfilesService.get_default()

local function format_rate_short(bps)
    bps = tonumber(bps) or 0
    if bps >= 1048576 then
        return string.format("%.1f MB/s", bps / 1048576)
    elseif bps >= 1024 then
        return string.format("%.0f KB/s", bps / 1024)
    end
    return string.format("%.0f B/s", bps)
end

local function format_mmss(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end


local function SplitTile(props)
    local icon_label = widgets.Label({
        label = props.glyph or "circle",
        css_classes = { "qs-tile-glyph" },
    })
    local title_label = widgets.Label({
        label = props.title or "",
        halign = "start",
        ellipsize = "end",
        css_classes = { "qs-tile-title" },
    })
    local sub_label = widgets.Label({
        label = props.subtitle or "",
        halign = "start",
        ellipsize = "end",
        css_classes = { "qs-tile-sub" },
    })

    local has_expand = (props.on_expand ~= nil)

    local main_btn = widgets.Button({
        hexpand = true,
        css_classes = { "qs-tile-main", (not has_expand) and "full-tile" or "" },
        on_click = props.on_toggle,
        child = widgets.Box({
            spacing = 10,
            valign = "center",
            child = {
                icon_label,
                widgets.Box({
                    vertical = true,
                    valign = "center",
                    hexpand = true,
                    child = { title_label, sub_label },
                }),
            },
        }),
    })

    local children = { main_btn }
    local chevron_btn = nil
    if has_expand then
        chevron_btn = widgets.Button({
            css_classes = { "qs-tile-chevron" },
            tooltip_text = "Expand options",
            on_click = props.on_expand,
            child = widgets.Label({
                label = "expand_more",
                css_classes = { "chevron-glyph" },
            }),
        })
        children[#children + 1] = chevron_btn
    end

    local root = widgets.Box({
        css_classes = { "qs-split-tile", props.active and "active" or "" },
        child = children,
    })

    return {
        root = root,
        icon = icon_label,
        title = title_label,
        subtitle = sub_label,
        chevron = chevron_btn,
        set_active = function(active)
            root:toggle_css_class("active", active and true or false)
        end,
        set_expanded = function(expanded)
            root:toggle_css_class("expanded", expanded and true or false)
        end,
    }
end


local function create_media_card()
    local art_icon = widgets.Icon({
        image = "audio-x-generic-symbolic",
        pixel_size = 42,
        css_classes = { "qs-media-art" },
    })
    local title_lbl = widgets.Label({
        label = "Not Playing",
        halign = "start",
        ellipsize = "end",
        hexpand = true,
        css_classes = { "qs-media-title" },
    })
    local artist_lbl = widgets.Label({
        label = "",
        halign = "start",
        ellipsize = "end",
        hexpand = true,
        css_classes = { "qs-media-artist" },
    })
    local play_icon = widgets.Label({
        label = "play_arrow",
        css_classes = { "m3-button-icon" },
    })
    local progress_bar = widgets.ProgressBar({
        value = 0,
        hexpand = true,
        css_classes = { "qs-media-progress" },
    })
    local time_lbl = widgets.Label({
        label = "0:00 / 0:00",
        css_classes = { "qs-media-time", "monospace-num" },
    })

    local active_player = nil

    local prev_btn = widgets.Button({
        css_classes = { "m3-button", "surface", "xs", "icon-only" },
        on_click = function()
            if active_player and active_player.previous then
                pcall(function() active_player:previous() end)
            end
        end,
        child = widgets.Label({ label = "skip_previous", css_classes = { "m3-button-icon" } }),
    })
    m3.enhance_button(prev_btn)

    local play_btn = widgets.Button({
        css_classes = { "m3-button", "filled", "xs", "icon-only" },
        on_click = function()
            if active_player and active_player.play_pause then
                pcall(function() active_player:play_pause() end)
            end
        end,
        child = play_icon,
    })
    m3.enhance_button(play_btn)

    local next_btn = widgets.Button({
        css_classes = { "m3-button", "surface", "xs", "icon-only" },
        on_click = function()
            if active_player and active_player.next then
                pcall(function() active_player:next() end)
            end
        end,
        child = widgets.Label({ label = "skip_next", css_classes = { "m3-button-icon" } }),
    })
    m3.enhance_button(next_btn)

    local card = widgets.Box({
        vertical = true,
        spacing = 8,
        visible = false,
        css_classes = { "qs-media-card" },
        child = {
            widgets.Box({
                spacing = 12,
                valign = "center",
                child = {
                    art_icon,
                    widgets.Box({
                        vertical = true,
                        valign = "center",
                        hexpand = true,
                        child = { title_lbl, artist_lbl },
                    }),
                    widgets.Box({
                        spacing = 4,
                        valign = "center",
                        child = { prev_btn, play_btn, next_btn },
                    }),
                },
            }),
            widgets.Box({
                spacing = 8,
                valign = "center",
                child = { progress_bar, time_lbl },
            }),
        },
    })

    local function sync_media()
        local players = mpris.players or {}
        active_player = mpris.active_player or players[#players]
        if not active_player then
            card.visible = false
            return
        end
        card.visible = true
        title_lbl.label = (active_player.title and active_player.title ~= "") and active_player.title or "Media Track"
        artist_lbl.label = (active_player.artist and active_player.artist ~= "") and active_player.artist or (active_player.identity or "Active Player")
        play_icon.label = (active_player.playback_status == "Playing") and "pause" or "play_arrow"

        local len = tonumber(active_player.length) or 0
        local pos = tonumber(active_player.position) or 0
        progress_bar.value = (len > 0) and math.max(0, math.min(1, pos / len)) or 0
        time_lbl.label = string.format("%s / %s", format_mmss(pos), format_mmss(len))

        local art = active_player.art_url or ""
        if art:sub(1, 7) == "file://" then
            art = art:sub(8):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        end
        art_icon.image = (art ~= "") and art or "audio-x-generic-symbolic"
    end

    mpris:connect("player-added", function(_, p)
        if p then
            p:connect("notify::title", sync_media)
            p:connect("notify::artist", sync_media)
            p:connect("notify::playback_status", sync_media)
            p:connect("notify::position", sync_media)
            p:connect("notify::art_url", sync_media)
        end
        sync_media()
    end)
    utils.Poll(2000, sync_media)
    sync_media()

    return card
end


local QuickCenter = {}
QuickCenter.__index = QuickCenter

function QuickCenter.new()
    local self = setmetatable({
        _expanded_section = nil,
        _tiles = {},
        _caffeine_active = false,
    }, QuickCenter)

    self.scheme_chip = widgets.Label({
        label = user_settings.appearance.wallcolors:bind("color_scheme", function(s)
            return tostring(s or "expressive"):upper():gsub("_", "-")
        end),
        css_classes = { "qs-status-chip", "monospace-num" },
        visible = false,
    })

    local header_row = widgets.Box({
        spacing = 8,
        valign = "center",
        css_classes = { "qs-header" },
        child = {
            m3.ShapeBadge({
                shape = "Cookie9Sided",
                size = 28,
                css_classes = { "qs-header-shape" },
            }),
            self.scheme_chip,
            widgets.Label({
                label = "Quick Center",
                hexpand = true,
                halign = "start",
                css_classes = { "qs-header-title" },
            }),
            m3.enhance_button(widgets.Button({
                css_classes = { "m3-button", "surface", "xs", "icon-only" },
                tooltip_text = "Material 3 Expressive Studio & Benchmark",
                on_click = function()
                    self:open_window("M3Test")
                end,
                child = widgets.Label({ label = "science", css_classes = { "m3-button-icon" } }),
            })),
            m3.enhance_button(widgets.Button({
                css_classes = { "m3-button", "surface", "xs", "icon-only" },
                tooltip_text = "Reload M3 Styles in-place",
                on_click = function()
                    css_manager:reload_all_css()
                end,
                child = widgets.Label({ label = "refresh", css_classes = { "m3-button-icon" } }),
            })),
            m3.enhance_button(widgets.Button({
                css_classes = { "m3-button", "surface", "xs", "icon-only" },
                tooltip_text = "Open Exo Settings",
                on_click = function()
                    self:open_window("Settings")
                end,
                child = widgets.Label({ label = "settings", css_classes = { "m3-button-icon" } }),
            })),
            m3.enhance_button(widgets.Button({
                css_classes = { "m3-button", "tonal", "xs", "icon-only" },
                tooltip_text = "Power Menu",
                on_click = function()
                    self:open_window("PowerMenu")
                end,
                child = widgets.Label({ label = "power_settings_new", css_classes = { "m3-button-icon" } }),
            })),
        },
    })

    local telemetry_island = self:_build_telemetry_island()
    local dev_tools_bar = self:_build_dev_tools_bar()

    self.accordion_box = widgets.Box({
        vertical = true,
        spacing = 6,
        css_classes = { "qs-accordion-box" },
    })
    self.accordion_revealer = widgets.Revealer({
        transition_type = "slide_down",
        transition_duration = 200,
        reveal_child = false,
        child = self.accordion_box,
    })

    self.wifi_tile = SplitTile({
        glyph = "wifi",
        title = "Wi-Fi",
        subtitle = "Checking...",
        active = network.wifi.enabled,
        on_toggle = function()
            network.wifi.enabled = not network.wifi.enabled
            self:_sync_tiles()
        end,
        on_expand = function()
            self:_toggle_accordion("wifi", function(box)
                self:_build_wifi_accordion(box)
            end)
        end,
    })

    self.bt_tile = SplitTile({
        glyph = "bluetooth",
        title = "Bluetooth",
        subtitle = bluetooth.powered and "Active" or "Off",
        active = bluetooth.powered,
        on_toggle = function()
            bluetooth.powered = not bluetooth.powered
            self:_sync_tiles()
        end,
        on_expand = function()
            self:_toggle_accordion("bt", function(box)
                self:_build_bt_accordion(box)
            end)
        end,
    })

    self.audio_tile = SplitTile({
        glyph = "volume_up",
        title = "Sound",
        subtitle = audio.speaker.description or "Default",
        active = not audio.speaker.is_muted,
        on_toggle = function()
            audio.speaker:toggle_mute()
            self:_sync_tiles()
        end,
        on_expand = function()
            self:_toggle_accordion("audio", function(box)
                self:_build_audio_accordion(box)
            end)
        end,
    })

    self.dark_tile = SplitTile({
        glyph = "dark_mode",
        title = "Theme",
        subtitle = "M3 Expressive",
        active = user_settings.appearance.wallcolors.dark_mode,
        on_toggle = function()
            local next_val = not user_settings.appearance.wallcolors.dark_mode
            Wallpaper.set_dark_mode(next_val)
            self:_sync_tiles()
        end,
        on_expand = function()
            self:_toggle_accordion("scheme", function(box)
                self:_build_scheme_accordion(box)
            end)
        end,
    })

    self.dnd_tile = SplitTile({
        glyph = "notifications_active",
        title = "Focus / DND",
        subtitle = notifications.dnd and "Silent" or "Normal",
        active = notifications.dnd,
        on_toggle = function()
            notifications.dnd = not notifications.dnd
            self:_sync_tiles()
        end,
        on_expand = function()
            self:_toggle_accordion("dnd", function(box)
                self:_build_dnd_accordion(box)
            end)
        end,
    })

    self.power_tile = SplitTile({
        glyph = "bolt",
        title = "Performance",
        subtitle = power_profiles.active_profile or "balanced",
        active = (power_profiles.active_profile == "performance") or recorder_script.recorder.active,
        on_toggle = function()
            if power_profiles.is_available then
                power_profiles:cycle_profile()
            else
                recorder_script.record_screen()
            end
            self:_sync_tiles()
        end,
        on_expand = function()
            self:_toggle_accordion("power", function(box)
                self:_build_power_accordion(box)
            end)
        end,
    })

    self._tiles = {
        wifi = self.wifi_tile,
        bt = self.bt_tile,
        audio = self.audio_tile,
        scheme = self.dark_tile,
        dnd = self.dnd_tile,
        power = self.power_tile,
    }

    local tiles_grid = widgets.Grid({
        column_spacing = 8,
        row_spacing = 8,
        column_homogeneous = true,
        child = {
            { self.wifi_tile.root,  col = 0, row = 0 },
            { self.bt_tile.root,    col = 1, row = 0 },
            { self.audio_tile.root, col = 0, row = 1 },
            { self.dark_tile.root,  col = 1, row = 1 },
            { self.dnd_tile.root,   col = 0, row = 2 },
            { self.power_tile.root, col = 1, row = 2 },
        },
    })

    local quick_sliders = quick_widgets.QuickSliders.new()
    local media_card = create_media_card()
    local notification_center = quick_widgets.NotificationCenter.new()

    self.content_box = widgets.Box({
        vertical = true,
        spacing = 10,
        hexpand = false,
        css_classes = { "panel-surface", "quickcenter-surface", "quick-center" },
        child = {
            header_row,
            telemetry_island,
            dev_tools_bar,
            tiles_grid,
            self.accordion_revealer,
            quick_sliders:widget(),
            media_card,
            notification_center:widget(),
        },
    })
    self.content_box.width_request = 420

    self.revealer = widgets.Revealer({
        transition_type = "slide_down",
        transition_duration = 240,
        child = self.content_box,
    })

    local close_button = widgets.Button({
        vexpand = true,
        hexpand = true,
        can_focus = false,
        css_classes = { "scrim-backdrop" },
        on_click = function()
            window_manager:close_window("QuickCenter")
        end,
    })

    local main_overlay = widgets.Overlay({
        css_classes = { "popup-close" },
        child = close_button,
        overlays = { self.revealer },
    })

    self.window = widgets.RevealerWindow({
        revealer = self.revealer,
        child = main_overlay,
        css_classes = { "popup-close" },
        hide_on_close = true,
        visible = false,
        namespace = "QuickCenter",
        popup = true,
        layer = "overlay",
        kb_mode = "on_demand",
        anchor = { "left", "right", "top", "bottom" },
    })

    self.window.update_side = function()
        self:update_side()
    end

    self.window_manager = window_manager
    self.notification_center = notification_center
    self.actual_content_box = self.revealer

    network.wifi:connect("notify::enabled", function() self:_sync_tiles() end)
    network.wifi:connect("notify::is_connected", function() self:_sync_tiles() end)
    network.wifi:connect("notify::ssid", function() self:_sync_tiles() end)
    network.ethernet:connect("notify::is_connected", function() self:_sync_tiles() end)

    bluetooth:connect("notify::powered", function() self:_sync_tiles() end)
    bluetooth:connect("notify::connected_devices", function() self:_sync_tiles() end)

    if audio.speaker then
        audio.speaker:connect("notify::is_muted", function() self:_sync_tiles() end)
        audio.speaker:connect("notify::description", function() self:_sync_tiles() end)
        audio.speaker:connect("notify::volume", function() self:_sync_tiles() end)
    end

    notifications:connect("notify::dnd", function() self:_sync_tiles() end)
    power_profiles:connect("notify::active_profile", function() self:_sync_tiles() end)

    self.window:connect("notify::visible", function()
        if self.window.visible then
            self:_sync_tiles()
            self:_update_telemetry_island()
        else
            self.accordion_revealer.reveal_child = false
            self._expanded_section = nil
            for _, t in pairs(self._tiles) do
                t.set_expanded(false)
            end
        end
    end)

    self:_sync_tiles()
    self:update_side()

    return self
end

function QuickCenter:_build_telemetry_island()
    self._cpu_lbl = widgets.Label({ label = "0% · 0.00", halign = "end", css_classes = { "qs-tel-val", "monospace-num" } })
    self._cpu_bar = widgets.ProgressBar({ value = 0, hexpand = true, css_classes = { "qs-tel-bar", "cpu" } })

    self._ram_lbl = widgets.Label({ label = "0.0 / 0.0G", halign = "end", css_classes = { "qs-tel-val", "monospace-num" } })
    self._ram_bar = widgets.ProgressBar({ value = 0, hexpand = true, css_classes = { "qs-tel-bar", "ram" } })

    self._net_lbl = widgets.Label({ label = "↓ 0 B/s  ↑ 0 B/s", halign = "end", css_classes = { "qs-tel-val", "monospace-num" } })
    self._temp_lbl = widgets.Label({ label = "", halign = "end", visible = false, css_classes = { "qs-tel-val", "monospace-num" } })

    local function metric_cell(icon, title, val_w, bar_w)
        return widgets.Box({
            vertical = true,
            spacing = 5,
            hexpand = true,
            css_classes = { "qs-tel-cell" },
            child = {
                widgets.Box({
                    spacing = 6,
                    valign = "center",
                    child = {
                        widgets.Label({ label = icon, css_classes = { "qs-tel-icon", "m3-icon" } }),
                        widgets.Label({ label = title, halign = "start", hexpand = true, css_classes = { "qs-tel-title" } }),
                        val_w,
                    },
                }),
                bar_w,
            },
        })
    end

    local island = widgets.Box({
        vertical = true,
        spacing = 8,
        css_classes = { "qs-telemetry-island" },
        child = {
            widgets.Box({
                spacing = 8,
                homogeneous = true,
                child = {
                    metric_cell("memory", "CPU", self._cpu_lbl, self._cpu_bar),
                    metric_cell("select_all", "RAM", self._ram_lbl, self._ram_bar),
                },
            }),
            widgets.Box({
                spacing = 8,
                valign = "center",
                css_classes = { "qs-tel-footer" },
                child = {
                    widgets.Label({ label = "swap_vert", css_classes = { "qs-tel-icon", "m3-icon" } }),
                    widgets.Label({ label = "NET I/O", halign = "start", css_classes = { "qs-tel-title" } }),
                    widgets.Box({ hexpand = true }),
                    self._net_lbl,
                    self._temp_lbl,
                },
            }),
        },
    })

    utils.Poll(2000, function()
        if self.window and self.window.visible then
            self:_update_telemetry_island()
        end
    end)

    return island
end

function QuickCenter:_update_telemetry_island()
    local t = utils.read_sys_telemetry()
    if not t or not self._cpu_lbl then return end

    local cpu = math.floor((t.cpu_percent or 0) + 0.5)
    local mem_pct = math.floor((t.mem_percent or 0) + 0.5)
    local used_g = (t.mem_used_kb or 0) / 1048576.0
    local tot_g = (t.mem_total_kb or 0) / 1048576.0
    local temp = math.floor((t.temp_c or 0) + 0.5)

    self._cpu_lbl.label = string.format("%d%% · %.2f", cpu, t.load_1m or 0)
    self._cpu_bar.value = math.max(0, math.min(1, cpu / 100.0))

    self._ram_lbl.label = string.format("%.1f / %.0fG", used_g, tot_g)
    self._ram_bar.value = math.max(0, math.min(1, mem_pct / 100.0))

    self._net_lbl.label = string.format("↓ %s  ↑ %s", format_rate_short(t.net_rx_bps), format_rate_short(t.net_tx_bps))
    if temp > 0 then
        self._temp_lbl.label = string.format(" · %d°C", temp)
        self._temp_lbl.visible = true
    else
        self._temp_lbl.visible = false
    end
end

function QuickCenter:_build_dev_tools_bar()
    local caffeine_btn = m3.Button.button({
        icon = "coffee",
        label = "Caffeine",
        size = "xs",
        shape = "square",
        hexpand = true,
        tooltip_text = "Inhibit screen idle & lock during builds",
        on_click = function(btn)
            self._caffeine_active = not self._caffeine_active
            btn:toggle_css_class("active", self._caffeine_active)
            if self._caffeine_active then
                utils.exec_sh_async("systemd-inhibit --what=idle --who='Exo Shell' --why='Developer Caffeine' sleep 86400 >/dev/null 2>&1 &")
                send_notification("Caffeine Enabled", "Screen idle and lock are inhibited.")
            else
                utils.exec_sh_async("pkill -f 'Developer Caffeine' 2>/dev/null")
                send_notification("Caffeine Disabled", "Normal screen idle restored.")
            end
        end,
    })

    local picker_btn = m3.Button.button({
        icon = "colorize",
        label = "Picker",
        size = "xs",
        shape = "square",
        hexpand = true,
        tooltip_text = "Pick screen HEX color (hyprpicker)",
        on_click = function()
            window_manager:close_window("QuickCenter")
            utils.exec_sh_async("sleep 0.15 && (hyprpicker -a 2>/dev/null || grim -g \"$(slurp -p)\" -t ppm - | magick - -format '%[hex:p{0,0}]' info: | wl-copy)")
        end,
    })

    local capture_btn = m3.Button.button({
        icon = "screenshot_region",
        label = "Shot",
        size = "xs",
        shape = "square",
        hexpand = true,
        tooltip_text = "Capture screen region to clipboard",
        on_click = function()
            window_manager:close_window("QuickCenter")
            utils.exec_sh_async("sleep 0.15 && grim -g \"$(slurp)\" - | wl-copy")
        end,
    })

    local sysmon_btn = m3.Button.button({
        icon = "terminal",
        label = "btop",
        size = "xs",
        shape = "square",
        hexpand = true,
        tooltip_text = "Launch System Monitor (btop / htop)",
        on_click = function()
            window_manager:close_window("QuickCenter")
            utils.exec_sh_async("(kitty -e btop || foot -e btop || alacritty -e btop || kitty -e htop) 2>/dev/null &")
        end,
    })

    return m3.Button.connected_group(
        { caffeine_btn, picker_btn, capture_btn, sysmon_btn },
        { halign = "fill", hexpand = true }
    )
end

function QuickCenter:_sync_tiles()
    local wifi_on = network.wifi.enabled
    local ssid = network.wifi.ssid
    if network.ethernet.is_connected then
        self.wifi_tile.icon.label = "settings_ethernet"
        self.wifi_tile.subtitle.label = "Ethernet"
        self.wifi_tile.set_active(true)
    else
        self.wifi_tile.icon.label = wifi_on and "wifi" or "wifi_off"
        self.wifi_tile.subtitle.label = (wifi_on and ssid and ssid ~= "") and ssid or (wifi_on and "Enabled" or "Off")
        self.wifi_tile.set_active(wifi_on)
    end

    local bt_on = bluetooth.powered
    local bt_conn = bluetooth.connected_devices or {}
    self.bt_tile.icon.label = bt_on and (#bt_conn > 0 and "bluetooth_connected" or "bluetooth") or "bluetooth_disabled"
    if not bt_on then
        self.bt_tile.subtitle.label = "Off"
    elseif #bt_conn == 1 then
        self.bt_tile.subtitle.label = bt_conn[1].alias or bt_conn[1].name or "Connected"
    elseif #bt_conn > 1 then
        self.bt_tile.subtitle.label = tostring(#bt_conn) .. " connected"
    else
        self.bt_tile.subtitle.label = "Active"
    end
    self.bt_tile.set_active(bt_on)

    local spk = audio.speaker
    local muted = spk and spk.is_muted
    self.audio_tile.icon.label = muted and "volume_off" or "volume_up"
    self.audio_tile.subtitle.label = muted and "Muted" or ((spk and spk.description) or "Speaker")
    self.audio_tile.set_active(not muted)

    local is_dark = user_settings.appearance.wallcolors.dark_mode
    local scheme = tostring(user_settings.appearance.wallcolors.color_scheme or "expressive")
    self.dark_tile.icon.label = is_dark and "dark_mode" or "light_mode"
    self.dark_tile.title.label = is_dark and "Dark Theme" or "Light Theme"
    self.dark_tile.subtitle.label = scheme:gsub("^%l", string.upper)
    self.dark_tile.set_active(is_dark)

    local dnd = notifications.dnd
    self.dnd_tile.icon.label = dnd and "notifications_off" or "notifications_active"
    self.dnd_tile.subtitle.label = dnd and "Silent (DND)" or "Alerts Active"
    self.dnd_tile.set_active(dnd)

    local rec = recorder_script.recorder.active
    local prof = power_profiles.active_profile or "balanced"
    if rec then
        self.power_tile.icon.label = "screen_record"
        self.power_tile.title.label = "Recording"
        self.power_tile.subtitle.label = "Tap to stop"
        self.power_tile.set_active(true)
    else
        self.power_tile.icon.label = (prof == "performance" and "local_fire_department")
            or (prof == "power-saver" and "eco") or "bolt"
        self.power_tile.title.label = "Power Mode"
        self.power_tile.subtitle.label = prof:gsub("^%l", string.upper)
        self.power_tile.set_active(prof == "performance")
    end
end

function QuickCenter:_toggle_accordion(section_name, builder_fn)
    if self._expanded_section == section_name and self.accordion_revealer.reveal_child then
        self.accordion_revealer.reveal_child = false
        self._expanded_section = nil
        for _, t in pairs(self._tiles) do
            t.set_expanded(false)
        end
        return
    end

    self._expanded_section = section_name
    for k, t in pairs(self._tiles) do
        t.set_expanded(k == section_name)
    end

    self.accordion_box:clear_children()
    builder_fn(self.accordion_box)
    self.accordion_revealer.reveal_child = true
end


function QuickCenter:_build_wifi_accordion(box)
    box:append(widgets.Box({
        spacing = 8,
        valign = "center",
        css_classes = { "qs-sub-header-row" },
        child = {
            widgets.Label({
                label = "Wi-Fi Networks",
                halign = "start",
                hexpand = true,
                css_classes = { "qs-sub-header" },
            }),
            widgets.Button({
                css_classes = { "qs-sub-action" },
                on_click = function()
                    network.wifi:scan(function()
                        if self._expanded_section == "wifi" then
                            self.accordion_box:clear_children()
                            self:_build_wifi_accordion(self.accordion_box)
                        end
                    end)
                end,
                child = widgets.Label({ label = "Scan" }),
            }),
            widgets.Button({
                css_classes = { "qs-sub-action" },
                on_click = function()
                    self:open_window("Settings")
                end,
                child = widgets.Label({ label = "All Settings" }),
            }),
        },
    }))

    if not network.wifi.enabled then
        box:append(widgets.Label({
            label = "Wi-Fi is turned off.",
            halign = "start",
            css_classes = { "qs-tile-sub" },
        }))
        return
    end

    local aps = network.wifi.access_points or {}
    if #aps == 0 then
        box:append(widgets.Label({
            label = "No networks found. Click Scan to refresh.",
            halign = "start",
            css_classes = { "qs-tile-sub" },
        }))
        return
    end

    for idx = 1, math.min(#aps, 6) do
        local ap = aps[idx]
        if ap and ap.ssid and ap.ssid ~= "" then
            local status_txt = ap.is_connected and "Connected"
                or ((ap.security and ap.security ~= "") and "Secured" or "Open")
            box:append(widgets.Button({
                css_classes = { "qs-sub-item", ap.is_connected and "active" or "" },
                on_click = function()
                    if ap.is_connected then
                        ap:disconnect_from(function() self:_sync_tiles() end)
                    else
                        ap:connect_to(nil, function() self:_sync_tiles() end)
                    end
                end,
                child = widgets.Box({
                    spacing = 10,
                    valign = "center",
                    child = {
                        widgets.Label({ label = "wifi", css_classes = { "sub-item-glyph" } }),
                        widgets.Label({
                            label = ap.ssid,
                            ellipsize = "end",
                            hexpand = true,
                            halign = "start",
                        }),
                        widgets.Label({
                            label = status_txt,
                            css_classes = { "qs-sub-status" },
                        }),
                    },
                }),
            }))
        end
    end
end

function QuickCenter:_build_bt_accordion(box)
    box:append(widgets.Box({
        spacing = 8,
        valign = "center",
        css_classes = { "qs-sub-header-row" },
        child = {
            widgets.Label({
                label = "Bluetooth Devices",
                halign = "start",
                hexpand = true,
                css_classes = { "qs-sub-header" },
            }),
            widgets.Button({
                css_classes = { "qs-sub-action" },
                on_click = function()
                    bluetooth.setup_mode = not bluetooth.setup_mode
                end,
                child = widgets.Label({ label = bluetooth.setup_mode and "Stop Scan" or "Scan" }),
            }),
            widgets.Button({
                css_classes = { "qs-sub-action" },
                on_click = function()
                    self:open_window("Settings")
                end,
                child = widgets.Label({ label = "Settings" }),
            }),
        },
    }))

    local devs = bluetooth.devices or {}
    if #devs == 0 then
        box:append(widgets.Label({
            label = bluetooth.powered and "No paired or discovered devices." or "Bluetooth is turned off.",
            halign = "start",
            css_classes = { "qs-tile-sub" },
        }))
        return
    end

    for _, dev in ipairs(devs) do
        local target_dev = dev
        local bat = (target_dev.battery_percentage and target_dev.battery_percentage >= 0)
            and (" • " .. tostring(target_dev.battery_percentage) .. "%") or ""
        local status_txt = (target_dev.connected and "Connected" or "Paired") .. bat

        box:append(widgets.Button({
            css_classes = { "qs-sub-item", target_dev.connected and "active" or "" },
            on_click = function()
                if target_dev.connected then
                    target_dev:disconnect_device(function() self:_sync_tiles() end)
                else
                    target_dev:connect_device(function() self:_sync_tiles() end)
                end
            end,
            child = widgets.Box({
                spacing = 10,
                valign = "center",
                child = {
                    widgets.Label({ label = "bluetooth", css_classes = { "sub-item-glyph" } }),
                    widgets.Label({
                        label = target_dev.alias or target_dev.name or "Device",
                        ellipsize = "end",
                        hexpand = true,
                        halign = "start",
                    }),
                    widgets.Label({
                        label = status_txt,
                        css_classes = { "qs-sub-status" },
                    }),
                },
            }),
        }))
    end
end

function QuickCenter:_build_audio_accordion(box)
    box:append(widgets.Label({
        label = "Audio Output (Speakers)",
        halign = "start",
        css_classes = { "qs-sub-header" },
    }))

    for _, spk in ipairs(audio.speakers or {}) do
        local target_spk = spk
        box:append(widgets.Button({
            css_classes = { "qs-sub-item", target_spk.is_default and "active" or "" },
            on_click = function()
                target_spk:make_default()
                self:_sync_tiles()
                if self._expanded_section == "audio" then
                    self.accordion_box:clear_children()
                    self:_build_audio_accordion(self.accordion_box)
                end
            end,
            child = widgets.Box({
                spacing = 10,
                valign = "center",
                child = {
                    widgets.Label({ label = "speaker", css_classes = { "sub-item-glyph" } }),
                    widgets.Label({
                        label = target_spk.description or "Speaker",
                        ellipsize = "end",
                        hexpand = true,
                        halign = "start",
                    }),
                    widgets.Label({
                        label = target_spk.is_default and "Default" or (tostring(target_spk.volume or 0) .. "%"),
                        css_classes = { "qs-sub-status" },
                    }),
                },
            }),
        }))
    end

    local mics = audio.microphones or {}
    if #mics > 0 then
        box:append(widgets.Label({
            label = "Audio Input (Microphones)",
            halign = "start",
            css_classes = { "qs-sub-header" },
        }))
        for _, mic in ipairs(mics) do
            local target_mic = mic
            box:append(widgets.Button({
                css_classes = { "qs-sub-item", target_mic.is_default and "active" or "" },
                on_click = function()
                    target_mic:make_default()
                    if self._expanded_section == "audio" then
                        self.accordion_box:clear_children()
                        self:_build_audio_accordion(self.accordion_box)
                    end
                end,
                child = widgets.Box({
                    spacing = 10,
                    valign = "center",
                    child = {
                        widgets.Label({ label = "mic", css_classes = { "sub-item-glyph" } }),
                        widgets.Label({
                            label = target_mic.description or "Microphone",
                            ellipsize = "end",
                            hexpand = true,
                            halign = "start",
                        }),
                        widgets.Label({
                            label = target_mic.is_default and "Active" or "Input",
                            css_classes = { "qs-sub-status" },
                        }),
                    },
                }),
            }))
        end
    end
end

function QuickCenter:_build_scheme_accordion(box)
    box:append(widgets.Label({
        label = "Material 3 Color Scheme",
        halign = "start",
        css_classes = { "qs-sub-header" },
    }))

    local schemes = {
        { id = "expressive",  title = "M3 Expressive", desc = "Shifted vibrant tertiary & high-contrast containers" },
        { id = "tonal-spot",  title = "Tonal Spot",    desc = "Balanced calm Material You palette" },
        { id = "vibrant",     title = "Vibrant",       desc = "Maximum chroma accent colors" },
        { id = "rainbow",     title = "Rainbow",       desc = "Chromatic hue shifts across surfaces" },
        { id = "fruit-salad", title = "Fruit Salad",   desc = "Playful dual-hue contrast" },
        { id = "fidelity",    title = "Fidelity",      desc = "Exact source wallpaper color fidelity" },
        { id = "monochrome",  title = "Monochrome",    desc = "Pure grayscale tonal hierarchy" },
    }

    local current = tostring(user_settings.appearance.wallcolors.color_scheme or "expressive"):gsub("_", "-")
    for _, sc in ipairs(schemes) do
        local target_sc = sc
        local is_active = (current == target_sc.id)
        box:append(widgets.Button({
            css_classes = { "qs-sub-item", is_active and "active" or "" },
            on_click = function()
                Wallpaper.set_colors(target_sc.id)
                self:_sync_tiles()
                if self._expanded_section == "scheme" then
                    self.accordion_box:clear_children()
                    self:_build_scheme_accordion(self.accordion_box)
                end
            end,
            child = widgets.Box({
                spacing = 10,
                valign = "center",
                child = {
                    widgets.Label({ label = "palette", css_classes = { "sub-item-glyph" } }),
                    widgets.Label({
                        label = target_sc.title,
                        ellipsize = "end",
                        hexpand = true,
                        halign = "start",
                    }),
                    widgets.Label({
                        label = is_active and "Active" or "Apply",
                        css_classes = { "qs-sub-status" },
                    }),
                },
            }),
        }))
    end
end

function QuickCenter:_build_dnd_accordion(box)
    box:append(widgets.Label({
        label = "Notification Controls",
        halign = "start",
        css_classes = { "qs-sub-header" },
    }))

    box:append(widgets.Button({
        css_classes = { "qs-sub-item", user_settings.interface.notifications.compact_popup and "active" or "" },
        on_click = function()
            local next_c = not user_settings.interface.notifications.compact_popup
            user_settings.interface.notifications.set_compact_popup(next_c)
            if self._expanded_section == "dnd" then
                self.accordion_box:clear_children()
                self:_build_dnd_accordion(self.accordion_box)
            end
        end,
        child = widgets.Box({
            spacing = 10,
            child = {
                widgets.Label({ label = "view_compact", css_classes = { "sub-item-glyph" } }),
                widgets.Label({ label = "Compact Notification Popups", hexpand = true, halign = "start" }),
                widgets.Label({
                    label = user_settings.interface.notifications.compact_popup and "On" or "Off",
                    css_classes = { "qs-sub-status" },
                }),
            },
        }),
    }))

    box:append(widgets.Button({
        css_classes = { "qs-sub-item" },
        on_click = function()
            send_notification("Exo Shell M3 Expressive", "Spring physics and Expressive tokens are active.")
        end,
        child = widgets.Box({
            spacing = 10,
            child = {
                widgets.Label({ label = "notifications_unread", css_classes = { "sub-item-glyph" } }),
                widgets.Label({ label = "Send Test Notification", hexpand = true, halign = "start" }),
                widgets.Label({ label = "Send", css_classes = { "qs-sub-status" } }),
            },
        }),
    }))
end

function QuickCenter:_build_power_accordion(box)
    box:append(widgets.Label({
        label = "Power Profiles & Screen Recording",
        halign = "start",
        css_classes = { "qs-sub-header" },
    }))

    for _, prof in ipairs({ "power-saver", "balanced", "performance" }) do
        local p = prof
        local is_active = (power_profiles.active_profile == p)
        box:append(widgets.Button({
            css_classes = { "qs-sub-item", is_active and "active" or "" },
            on_click = function()
                power_profiles.active_profile = p
                self:_sync_tiles()
                if self._expanded_section == "power" then
                    self.accordion_box:clear_children()
                    self:_build_power_accordion(self.accordion_box)
                end
            end,
            child = widgets.Box({
                spacing = 10,
                child = {
                    widgets.Label({
                        label = (p == "performance" and "local_fire_department") or (p == "power-saver" and "eco") or "bolt",
                        css_classes = { "sub-item-glyph" },
                    }),
                    widgets.Label({ label = "Profile: " .. p:gsub("^%l", string.upper), hexpand = true, halign = "start" }),
                    widgets.Label({ label = is_active and "Active" or "Set", css_classes = { "qs-sub-status" } }),
                },
            }),
        }))
    end

    box:append(widgets.Button({
        css_classes = { "qs-sub-item", recorder_script.recorder.active and "active" or "" },
        on_click = function()
            recorder_script.record_screen()
            self:_sync_tiles()
        end,
        child = widgets.Box({
            spacing = 10,
            child = {
                widgets.Label({ label = "screen_record", css_classes = { "sub-item-glyph" } }),
                widgets.Label({
                    label = recorder_script.recorder.active and "Stop Screen Recording" or "Record Full Screen",
                    hexpand = true,
                    halign = "start",
                }),
                widgets.Label({
                    label = recorder_script.recorder.active and "Recording" or "Start",
                    css_classes = { "qs-sub-status" },
                }),
            },
        }),
    }))

    box:append(widgets.Button({
        css_classes = { "qs-sub-item" },
        on_click = function()
            window_manager:close_window("QuickCenter")
            recorder_script.record_region()
        end,
        child = widgets.Box({
            spacing = 10,
            child = {
                widgets.Label({ label = "screenshot_region", css_classes = { "sub-item-glyph" } }),
                widgets.Label({ label = "Record Screen Region (Slurp)", hexpand = true, halign = "start" }),
                widgets.Label({ label = "Region", css_classes = { "qs-sub-status" } }),
            },
        }),
    }))
end


function QuickCenter:open_window(window)
    window_manager:close_window("QuickCenter")
    window_manager:open_window(window)
end

function QuickCenter:toggle_window()
    self.window.visible = not self.window.visible
end

function QuickCenter:update_side()
    local modules = user_settings.interface.modules
    local location = modules.location.systeminfotray
    local bar_id = modules.bar_id.systeminfotray or 0
    local bar = (bar_id == 1) and user_settings.interface.bar2 or user_settings.interface.bar
    local side = bar.side

    local halign
    if side == "left" or side == "right" then
        halign = (side == "left") and "start" or "end"
    else
        if location == 1 then
            halign = "center"
        else
            halign = (location == 0) and "start" or "end"
        end
    end

    self.actual_content_box:set_halign(halign)
    self.content_box:set_halign(halign)

    if halign == "start" then
        self.revealer.transition_type = "slide_right"
    elseif halign == "center" then
        self.revealer.transition_type = "slide_down"
    else
        self.revealer.transition_type = "slide_left"
    end

    self.actual_content_box:queue_resize()
end

setmetatable(QuickCenter, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
})

return QuickCenter
