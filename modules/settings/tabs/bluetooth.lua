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

local BluetoothTab = {}
BluetoothTab.__index = BluetoothTab

function BluetoothTab.new()
    local self = setmetatable({
        _connected_devs = setmetatable({}, { __mode = "k" }),
    }, BluetoothTab)

    self.bluetooth_service = services.BluetoothService.get_default()

    if self.bluetooth_service.state == "absent" then
        self.box = widgets.Box({
            vertical = true,
            spacing = 20,
            css_classes = { "settings-body" },
            hexpand = false,
            halign = "center",
            width_request = 800,
            child = {
                widgets.Label({
                    label = "No Bluetooth Found",
                    halign = "center",
                    vexpand = true,
                }),
            },
        })
        return self
    end

    self.box = widgets.Box({
        vertical = true,
        spacing = 8,
        css_classes = { "settings-body" },
        hexpand = false,
        halign = "center",
        width_request = 800,
    })

    self.adapter_category = self:create_adapter_category()
    self.device_category = self:create_device_category()

    self.box:append(self.adapter_category)
    self.box:append(widgets.Separator())
    self.box:append(self.device_category)

    self.scan_status_label = widgets.Label({ label = "" })
    self.scan_button = Button.button({
        icon = "bluetooth_searching",
        label = "Scan for Devices",
        on_click = function()
            self:start_scan()
        end,
    })
    self.box:append(widgets.Separator())
    self.box:append(SettingsRow({
        title = "Scan for Devices",
        description = "Actively search for new Bluetooth devices in your vicinity.",
        child = { self.scan_button },
    }))
    self.box:append(widgets.Separator())

    self.box:append(SettingsRow({
        title = "Open Bluetooth Settings",
        description = "Open the Bluetooth panel in the GNOME Settings application for advanced configuration.",
        child = {
            Button.button({
                icon = "barefoot",
                label = "Open Settings",
                on_click = function()
                    self:_open_gnome_settings()
                end,
            }),
        },
    }))

    self.bluetooth_service:connect("notify::powered", function()
        self:update_ui()
    end)
    self.bluetooth_service:connect("device-added", function()
        self:update_ui()
    end)

    self:update_ui()

    return self
end

function BluetoothTab:start_scan()
    self.scan_button:set_sensitive(false)

    self.device_list_box:clear()
    self.device_list_box:append(widgets.Label({
        label = "Scanning...",
        halign = "center",
        vexpand = true,
    }))

    self.bluetooth_service.setup_mode = true

    utils.Timeout(15000, function()
        self.bluetooth_service.setup_mode = false
        self.scan_button:set_sensitive(true)
        self:update_ui()
    end)
end

function BluetoothTab:update_ui()
    if self.powered_switch_row and self.powered_switch_row.switch then
        self.powered_switch_row.switch:set_active(self.bluetooth_service.powered and true or false)
    end

    if not self.device_list_box then return end
    self.device_list_box:clear()

    if self.bluetooth_service.powered then
        local found_devices = self.bluetooth_service.devices or {}
        if #found_devices == 0 then
            self.device_list_box:append(widgets.Label({
                label = "No devices found.",
                halign = "center",
                vexpand = true,
                css_classes = { "no-devices-label" },
            }))
        else
            for _, device in ipairs(found_devices) do
                local dev = device
                self.device_list_box:append(self:create_device_row(dev))
                if not self._connected_devs[dev] then
                    self._connected_devs[dev] = true
                    dev:connect("removed", function()
                        self:update_ui()
                    end)
                    dev:connect("notify::connected", function()
                        self:update_ui()
                    end)
                end
            end
        end
    else
        self.device_list_box:append(widgets.Label({
            label = "Bluetooth is off.",
            halign = "center",
            vexpand = true,
        }))
    end
end

function BluetoothTab:_open_gnome_settings()
    local has_cc = ignis.GLib and ignis.GLib.find_program_in_path
        and ignis.GLib.find_program_in_path("gnome-control-center") ~= nil
    if not has_cc then
        send_notification("Error", "GNOME Control Center not found.")
        return
    end
    utils.exec_sh_async("XDG_CURRENT_DESKTOP=GNOME gnome-control-center bluetooth")
end

function BluetoothTab:create_device_row(device)
    local row_content = widgets.Box({ spacing = 10, halign = "fill", hexpand = true })

    row_content:append(widgets.Label({
        label = device.icon_name,
        css_classes = { "material-symbols", "icon-label" },
        margin_start = 10,
    }))
    row_content:append(widgets.Label({
        label = device.alias,
        hexpand = true,
        halign = "start",
    }))

    local button_handler
    if device.connected then
        row_content:append(widgets.Label({
            label = "Connected",
            css_classes = { "connected-status-label" },
        }))
        button_handler = function()
            device:disconnect_from()
        end
    else
        row_content:append(widgets.Label({
            label = "Not Connected",
            css_classes = { "status-label" },
        }))
        button_handler = function()
            device:connect_to()
        end
    end

    return widgets.Button({
        on_click = button_handler,
        child = row_content,
        css_classes = { "network-row" },
    })
end

function BluetoothTab:create_adapter_category()
    local box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
    })
    box:append(CategoryLabel({ title = "Bluetooth Adapter" }))

    local bluetooth_service = self.bluetooth_service
    self.powered_switch_row = SwitchRow(
        bluetooth_service.powered,
        function(_, active)
            bluetooth_service.powered = active
        end,
        {
            title = "Bluetooth",
            description = "Toggle the Bluetooth adapter on or off.",
        }
    )
    box:append(self.powered_switch_row)

    return box
end

function BluetoothTab:create_device_category()
    local box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
    })
    box:append(CategoryLabel({ title = "Devices" }))

    self.device_list_box = widgets.Box({
        vertical = true,
        spacing = 5,
        css_classes = { "network-list-container" },
    })
    box:append(SettingsRow({
        title = "Paired & Discovered Devices",
        description = "Select a device to connect.",
        vertical = true,
        child = { self.device_list_box },
    }))

    return box
end

function BluetoothTab:widget()
    return self.box
end

return BluetoothTab
