local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local services = ignis.services

local Button = require("modules.m3components").Button
local settings_widgets = require("modules.settings.widgets")
local send_notification = require("scripts.send_notification")

local CategoryLabel = settings_widgets.CategoryLabel
local SettingsRow = settings_widgets.SettingsRow
local SwitchRow = settings_widgets.SwitchRow

local NetworkTab = {}
NetworkTab.__index = NetworkTab

function NetworkTab.new()
    local self = setmetatable({}, NetworkTab)

    self.network_service = services.NetworkService.get_default()

    self.box = widgets.Box({
        vertical = true,
        spacing = 8,
        css_classes = { "settings-body" },
        hexpand = false,
        halign = "center",
        width_request = 800,
    })

    self.box:append(self:create_network_category())

    self.box:append(widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Miscellaneous" }),
            SettingsRow({
                title = "Open Network Settings",
                description = "Open the network panel in the GNOME Settings application for advanced configuration.",
                child = {
                    Button.button({
                        icon = "barefoot",
                        label = "Open Settings",
                        on_click = function()
                            self:_open_gnome_settings()
                        end,
                        hexpand = false,
                        halign = "start",
                    }),
                },
            }),
            widgets.Separator(),
            SettingsRow({
                title = "Refresh Network Status",
                description = "Manually refresh the status of all network connections.",
                child = {
                    Button.button({
                        icon = "refresh",
                        label = "Refresh",
                        on_click = function()
                            self:update_ui(true)
                        end,
                        hexpand = false,
                        halign = "start",
                    }),
                },
            }),
        },
    }))

    self.network_service.wifi:connect("notify::enabled", function()
        self:update_ui(false)
    end)
    self.network_service.ethernet:connect("notify::is_connected", function()
        self:update_ui(false)
    end)

    self:update_ui(false)

    return self
end

function NetworkTab:_open_gnome_settings()
    local has_cc = ignis.GLib and ignis.GLib.find_program_in_path
        and ignis.GLib.find_program_in_path("gnome-control-center") ~= nil
    if not has_cc then
        send_notification("Error", "GNOME Control Center not found.")
        return
    end
    utils.exec_sh_async("XDG_CURRENT_DESKTOP=GNOME gnome-control-center network")
end

function NetworkTab:_get_wifi_icon_name(ap)
    local is_secured = ap.security ~= ""
    local strength = ap.strength or 0

    local base_name
    if strength > 75 then
        base_name = "network_wifi_3_bar"
    elseif strength > 50 then
        base_name = "network_wifi_2_bar"
    elseif strength > 25 then
        base_name = "network_wifi_1_bar"
    else
        base_name = "network_wifi"
    end

    if is_secured then
        return base_name .. "_locked"
    end
    return base_name
end

function NetworkTab:_connect_wifi_and_refresh(ap)
    ap:connect_to(nil, function()
        self:update_ui(false)
    end)
end

function NetworkTab:_disconnect_wifi_and_refresh(ap)
    ap:disconnect_from(function()
        self:update_ui(false)
    end)
end

function NetworkTab:_populate_wifi_list(found_aps)
    self.wifi_list_box:clear()
    if #found_aps == 0 then
        self.wifi_list_box:append(widgets.Label({
            label = "No networks found.",
            halign = "center",
            vexpand = true,
            css_classes = { "no-networks-label" },
        }))
        return
    end

    for _, ap in ipairs(found_aps) do
        self.wifi_list_box:append(self:create_access_point_row(ap))
    end
end

function NetworkTab:update_ui(force_scan)
    if self.wifi_switch_row and self.wifi_switch_row.switch then
        self.wifi_switch_row.switch:set_active(self.network_service.wifi.enabled and true or false)
    end

    local eth_connected = self.network_service.ethernet.is_connected
    self.ethernet_status_label.label = eth_connected and "Connected" or "Disconnected"
    self.ethernet_status_label:set_css_classes({
        "status-label",
        eth_connected and "connected" or "disconnected",
    })

    local wifi_service = self.network_service.wifi

    if not wifi_service.enabled then
        self.wifi_list_box:clear()
        self.wifi_list_box:append(widgets.Label({
            label = "Wi-Fi is disabled.",
            halign = "center",
            vexpand = true,
        }))
        return
    end

    local devices = wifi_service.devices or {}
    if #devices == 0 then
        self:_populate_wifi_list(wifi_service.access_points or {})
        if force_scan then
            wifi_service:scan(function(aps)
                self:_populate_wifi_list(aps or {})
            end)
        end
        return
    end

    local current_aps = {}
    for _, dev in ipairs(devices) do
        for _, ap in ipairs(dev.access_points or {}) do
            current_aps[#current_aps + 1] = ap
        end
    end
    self:_populate_wifi_list(current_aps)

    if force_scan then
        local found_aps = {}
        local pending = #devices
        for _, device in ipairs(devices) do
            local dev = device
            dev:scan(function()
                for _, ap in ipairs(dev.access_points or {}) do
                    found_aps[#found_aps + 1] = ap
                end
                pending = pending - 1
                if pending == 0 then
                    self:_populate_wifi_list(found_aps)
                end
            end)
        end
    end
end

function NetworkTab:create_access_point_row(ap)
    local row_content = widgets.Box({ spacing = 10, halign = "fill", hexpand = true })

    row_content:append(widgets.Label({
        label = self:_get_wifi_icon_name(ap),
        css_classes = { "material-symbols", "icon-label" },
        margin_start = 10,
    }))
    row_content:append(widgets.Label({
        label = ap.ssid,
        hexpand = true,
        halign = "start",
    }))

    if ap.is_connected then
        row_content:append(widgets.Label({
            label = "Connected",
            css_classes = { "connected-status-label" },
        }))
        return widgets.Button({
            on_click = function()
                self:_disconnect_wifi_and_refresh(ap)
            end,
            child = row_content,
            css_classes = { "network-row" },
        })
    end

    return widgets.Button({
        on_click = function()
            self:_connect_wifi_and_refresh(ap)
        end,
        child = row_content,
        css_classes = { "network-row" },
    })
end

function NetworkTab:create_network_category()
    local box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
    })
    box:append(CategoryLabel({ title = "Wi-Fi & Ethernet" }))

    self.wifi_switch_row = SwitchRow(
        self.network_service.wifi.enabled,
        function(_, active)
            self.network_service.wifi.enabled = active
        end,
        {
            title = "Wi-Fi",
            description = "Toggle Wi-Fi on or off.",
        }
    )
    box:append(self.wifi_switch_row)
    box:append(widgets.Separator())

    self.wifi_list_box = widgets.Box({
        vertical = true,
        spacing = 5,
        css_classes = { "network-list-container" },
    })
    box:append(SettingsRow({
        title = "Available Networks",
        description = "Select a network to connect.",
        vertical = true,
        child = { self.wifi_list_box },
    }))
    box:append(widgets.Separator())

    self.ethernet_status_label = widgets.Label({
        label = "",
        css_classes = { "status-label" },
    })
    box:append(SettingsRow({
        title = "Ethernet Status",
        description = "Status of your Ethernet connection.",
        vertical = true,
        child = { self.ethernet_status_label },
    }))

    return box
end

function NetworkTab:widget()
    return self.box
end

return NetworkTab
