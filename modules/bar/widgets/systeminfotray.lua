local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local services = ignis.services
local window_manager = ignis.WindowManager.get_default()

local user_settings = require("user_settings")
local m3 = require("modules.m3components")
local Battery = require("modules.bar.widgets.battery")
local compositor = require("modules.compositor")

local system_tray = services.SystemTrayService.get_default()

local function bar_for(bar_id)
    if bar_id == 0 then
        return user_settings.interface.bar
    end
    return user_settings.interface.bar2
end

local function format_rate_short(bps)
    bps = tonumber(bps) or 0
    if bps >= 1048576 then
        return string.format("%.1fM/s", bps / 1048576)
    elseif bps >= 1024 then
        return string.format("%.0fK/s", bps / 1024)
    end
    return "0K/s"
end


local TrayItem = {}
TrayItem.__index = TrayItem

function TrayItem.new(item, on_removed_callback)
    local self = setmetatable({}, TrayItem)

    self.menu = item.menu and item.menu:create_popover() or nil

    local children = {
        widgets.Icon({
            image = item:bind("icon"),
            pixel_size = 16,
            css_classes = { "tray-icon" },
        }),
    }
    if self.menu then
        children[#children + 1] = self.menu
    end

    self.button = widgets.Button({
        child = widgets.Box({ child = children }),
        tooltip_text = item:bind("tooltip"),
        on_click = function()
            item:activate(0, 0)
        end,
        on_right_click = function()
            if self.menu then
                self.menu:popup()
            else
                item:context_menu(0, 0)
            end
        end,
        css_classes = { "tray-item", "unset" },
        halign = "center",
        valign = "center",
    })

    m3.enhance_button(self.button, {
        ink = "on_surface_variant",
        hover_bg = "surface_container_highest",
        radius = { rest = "pill", hover = 8, press = 5 },
    })

    item:connect("removed", function()
        if on_removed_callback then
            on_removed_callback()
        end
        self.button:unparent()
    end)

    return self
end

function TrayItem:widget()
    return self.button
end


local Tray = {}
Tray.__index = Tray

function Tray.new()
    local self = setmetatable({}, Tray)
    self.container = widgets.Box({ css_classes = { "tray" } })
    self:_setup()
    return self
end

function Tray:_setup()
    self:update_layout()
    self:update_visibility()

    system_tray:connect("added", function(_, item)
        self:_handle_added(item)
    end)

    for _, item in ipairs(system_tray.items or {}) do
        self.container:append(TrayItem.new(item, function()
            self:handle_item_removed()
        end):widget())
    end
end

function Tray:update_layout()
    local bar = bar_for(user_settings.interface.modules.bar_id.systeminfotray)
    local is_vertical = bar.vertical

    self.container:set_vertical(is_vertical)

    if is_vertical then
        self.container:set_hexpand(false)
        self.container:set_vexpand(true)
        self.container:set_spacing(2)
    else
        self.container:set_hexpand(true)
        self.container:set_vexpand(false)
        self.container:set_spacing(6)
    end
end

function Tray:update_visibility()
    self.container:set_visible(#(system_tray.items or {}) > 0)
end

function Tray:_handle_added(item)
    self.container:append(TrayItem.new(item, function()
        self:handle_item_removed()
    end):widget())
    self:update_visibility()
end

function Tray:handle_item_removed()
    self:update_visibility()
end

function Tray:widget()
    return self.container
end


local SystemInfoTray = {}
SystemInfoTray.__index = SystemInfoTray

function SystemInfoTray.new()
    local self = setmetatable({}, SystemInfoTray)

    self.tray_widget = Tray.new()
    self.battery_widget = Battery.new()

    self.network_service = services.NetworkService.get_default()
    self.bluetooth_service = services.BluetoothService.get_default()
    self.audio_service = services.AudioService.get_default()

    self.main_container = widgets.Box({ css_classes = { "system-info-tray" } })

    self.cpu_label = widgets.Label({
        label = "0%",
        css_classes = { "telemetry-val", "monospace-num" },
    })
    self.ram_label = widgets.Label({
        label = "0.0G",
        css_classes = { "telemetry-val", "monospace-num" },
    })
    self.telemetry_box = widgets.Box({
        spacing = 6,
        valign = "center",
        css_classes = { "bar-telemetry-chip" },
        child = {
            widgets.Box({
                spacing = 3,
                valign = "center",
                child = {
                    widgets.Label({ label = "memory", css_classes = { "icon", "telemetry-glyph" } }),
                    self.cpu_label,
                },
            }),
            widgets.Box({
                spacing = 3,
                valign = "center",
                child = {
                    widgets.Label({ label = "select_all", css_classes = { "icon", "telemetry-glyph" } }),
                    self.ram_label,
                },
            }),
        },
    })

    self.kb_label = widgets.Label({
        label = compositor.active_kb_layout(),
        css_classes = { "kb-code-label", "monospace-num" },
    })
    self.kb_button = widgets.Button({
        css_classes = { "bar-kb-pill", "unset" },
        valign = "center",
        halign = "center",
        tooltip_text = "Keyboard Layout: " .. tostring(compositor.kb_layout_full()) .. " (Click to switch)",
        on_click = function()
            compositor.switch_kb_layout()
        end,
        child = self.kb_label,
    })

    m3.enhance_button(self.kb_button, {
        ink = "on_surface",
        hover_bg = "surface_container_highest",
        radius = { rest = "pill", hover = 8, press = 8 },
    })

    local button_content = widgets.Box({})
    self.button = widgets.Button({
        child = button_content,
        css_classes = { "system-info-tray-container" },
        on_click = function()
            window_manager:toggle_window("QuickCenter")
        end,
    })

    self.wifi = widgets.Label({ css_classes = { "icon" } })
    self.bluetooth = widgets.Label({ css_classes = { "icon" } })

    self.audio_container = widgets.EventBox({
        on_right_click = function()
            self:_toggle_audio_mute()
        end,
        on_middle_click = function()
            self:_toggle_audio_mute()
        end,
        on_scroll_up = function()
            self:_on_audio_scroll_up()
        end,
        on_scroll_down = function()
            self:_on_audio_scroll_down()
        end,
        halign = "center",
        valign = "center",
    })
    self.audio = widgets.Label({
        halign = "center",
        valign = "fill",
        css_classes = { "icon" },
    })
    self.audio_container:append(self.audio)

    self.main_container:append(self.tray_widget:widget())
    self.main_container:append(self.kb_button)
    self.main_container:append(self.button)

    button_content:append(self.telemetry_box)
    button_content:append(self.wifi)
    button_content:append(self.bluetooth)
    button_content:append(self.audio_container)
    button_content:append(self.battery_widget:widget())

    local function update()
        self:_update_ui()
    end

    self.network_service.wifi:connect("notify::is_connected", update)
    self.network_service.ethernet:connect("notify::is_connected", update)
    self.network_service.vpn:connect("notify::is_connected", update)

    self.bluetooth_service:connect("notify::powered", update)
    self.bluetooth_service:connect("notify::connected_devices", update)
    self.bluetooth_service:connect("notify::devices", update)

    self.audio_service.speaker:connect("notify::is_muted", update)
    self.audio_service.speaker:connect("notify::volume", update)

    if compositor.service then
        compositor.service:connect("notify::kb_layout", function() self:_update_kb() end)
        compositor.service:connect("notify::active_kb_layout", function() self:_update_kb() end)
    end

    local opts = user_settings.interface.modules.options
    opts:connect_option("show_telemetry", function() self:update_layout() end)
    opts:connect_option("show_kb_layout", function() self:update_layout() end)

    utils.read_sys_telemetry()
    utils.Poll(2000, function()
        self:_update_telemetry()
    end)

    self:update_layout()
    return self
end

function SystemInfoTray:_update_kb()
    self.kb_label:set_label(compositor.active_kb_layout())
    self.kb_button:set_tooltip_text("Keyboard Layout: " .. tostring(compositor.kb_layout_full()) .. " (Click to switch)")
end

function SystemInfoTray:_update_telemetry()
    local opts = user_settings.interface.modules.options
    if opts.show_telemetry == false then return end

    local t = utils.read_sys_telemetry()
    if not t then return end

    local cpu = math.floor((t.cpu_percent or 0) + 0.5)
    local mem_gb = (t.mem_used_kb or 0) / 1048576.0
    local mem_tot_gb = (t.mem_total_kb or 0) / 1048576.0
    local mem_pct = math.floor((t.mem_percent or 0) + 0.5)
    local temp = math.floor((t.temp_c or 0) + 0.5)

    local bar = bar_for(user_settings.interface.modules.bar_id.systeminfotray)
    if bar.vertical then
        self.cpu_label:set_label(string.format("%d%%", cpu))
        self.ram_label:set_label(string.format("%d%%", mem_pct))
    else
        self.cpu_label:set_label(string.format("%2d%%", cpu))
        self.ram_label:set_label(string.format("%.1fG", mem_gb))
    end

    self.telemetry_box:toggle_css_class("warning", cpu >= 75 or mem_pct >= 80)
    self.telemetry_box:toggle_css_class("critical", cpu >= 90 or mem_pct >= 92)

    self.button:set_tooltip_text(string.format(
        "CPU: %d%% (Load %.2f, %.2f, %.2f)\nRAM: %.2f / %.2f GiB (%d%%)\nNet: ↓ %s  ↑ %s%s",
        cpu,
        t.load_1m or 0, t.load_5m or 0, t.load_15m or 0,
        mem_gb, mem_tot_gb, mem_pct,
        format_rate_short(t.net_rx_bps),
        format_rate_short(t.net_tx_bps),
        temp > 0 and string.format("\nTemp: %d°C", temp) or ""
    ))
end

function SystemInfoTray:_toggle_audio_mute()
    local speaker = self.audio_service.speaker
    speaker.is_muted = not speaker.is_muted
end

function SystemInfoTray:_on_audio_scroll_up()
    local speaker = self.audio_service.speaker
    speaker.volume = math.max(0, math.min(100, (speaker.volume or 0) - 5))
end

function SystemInfoTray:_on_audio_scroll_down()
    local speaker = self.audio_service.speaker
    speaker.volume = math.max(0, math.min(100, (speaker.volume or 0) + 5))
end

function SystemInfoTray:update_layout()
    local bar = bar_for(user_settings.interface.modules.bar_id.systeminfotray)
    local is_vertical = bar.vertical
    local opts = user_settings.interface.modules.options
    local button_content = self.button:get_child()

    self.telemetry_box:set_visible(opts.show_telemetry ~= false and not is_vertical)
    self.kb_button:set_visible(opts.show_kb_layout ~= false)

    if is_vertical then
        self.main_container:set_spacing(4)
        self.main_container:set_halign("fill")
        self.main_container:set_valign("center")
        self.main_container:set_hexpand(true)
        self.main_container:set_vexpand(false)
        self.main_container:set_vertical(true)
        button_content:set_vertical(true)
        button_content:set_spacing(5)
    else
        self.main_container:set_spacing(6)
        self.main_container:set_halign("center")
        self.main_container:set_valign("fill")
        self.main_container:set_hexpand(false)
        self.main_container:set_vexpand(true)
        self.main_container:set_vertical(false)
        button_content:set_vertical(false)
        button_content:set_spacing(8)
    end

    self.tray_widget:update_layout()
    self.battery_widget:update_layout()
    self:_update_ui()
    self:_update_telemetry()
    self:_update_kb()
end

function SystemInfoTray:_update_ui()
    local wifi = self.network_service.wifi
    local ethernet = self.network_service.ethernet

    if ethernet.is_connected then
        self.wifi:set_visible(true)
        self.wifi:set_label("settings_ethernet")
    elseif wifi.enabled then
        self.wifi:set_visible(true)
        local devices = wifi.devices or {}
        if wifi.is_connected and devices[1] and devices[1].ap then
            local strength = devices[1].ap.strength or 0
            if strength >= 75 then
                self.wifi:set_label("signal_wifi_4_bar")
            elseif strength >= 50 then
                self.wifi:set_label("network_wifi_3_bar")
            elseif strength >= 25 then
                self.wifi:set_label("network_wifi_2_bar")
            elseif strength > 0 then
                self.wifi:set_label("network_wifi_1_bar")
            else
                self.wifi:set_label("signal_wifi_0_bar")
            end
        else
            self.wifi:set_label("signal_wifi_off")
        end
    else
        self.wifi:set_visible(false)
    end

    local found_devices = self.bluetooth_service.devices or {}
    if #found_devices > 0 then
        self.bluetooth:set_visible(true)
        if self.bluetooth_service.powered then
            if #(self.bluetooth_service.connected_devices or {}) > 0 then
                self.bluetooth:set_label("bluetooth_connected")
            else
                self.bluetooth:set_label("bluetooth")
            end
        else
            self.bluetooth:set_label("bluetooth_disabled")
        end
    else
        self.bluetooth:set_visible(false)
    end

    local speaker = self.audio_service.speaker
    if speaker.is_muted then
        self.audio:set_label("volume_off")
    else
        local volume = speaker.volume or 0
        if volume < 33 then
            self.audio:set_label("volume_mute")
        elseif volume < 67 then
            self.audio:set_label("volume_down")
        else
            self.audio:set_label("volume_up")
        end
    end
end

function SystemInfoTray:widget()
    return self.main_container
end

return SystemInfoTray
