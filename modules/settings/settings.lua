local ignis = require("ignis")
local widgets = ignis.widgets

local Button = require("modules.m3components").Button
local NavigationRail = require("modules.m3components").NavigationRail

local QuickTab = require("modules.settings.tabs.quick")
local AppearanceTab = require("modules.settings.tabs.appearance")
local InterfaceTab = require("modules.settings.tabs.interface")
local ServicesTab = require("modules.settings.tabs.services")
local NetworkTab = require("modules.settings.tabs.network")
local BluetoothTab = require("modules.settings.tabs.bluetooth")
local AboutTab = require("modules.settings.tabs.about")

local TAB_MODULES = {
    quick = QuickTab,
    appearance = AppearanceTab,
    interface = InterfaceTab,
    services = ServicesTab,
    network = NetworkTab,
    bluetooth = BluetoothTab,
    about = AboutTab,
}

local TAB_ORDER = {
    "quick",
    "appearance",
    "interface",
    "services",
    "network",
    "bluetooth",
    "about",
}

local Settings = {}
Settings.__index = Settings

function Settings.new()
    local self = setmetatable({
        _tab_cache = {},
        _tab_instances = {},
        _active_key = "quick",
        _initialized = false,
    }, Settings)

    self.reload_button = Button.button({
        icon = "restart_alt",
        type = "tonal",
        visible = true,
        shape = "square",
        on_click = function()
            ignis.App.get_initialized():reload()
        end,
        css_classes = { "reload-button" },
        tooltip_text = "Reload Exo",
    })

    self.content_scroll = widgets.Scroll({
        hexpand = true,
        vexpand = true,
        halign = "fill",
        valign = "fill",
        hscrollbar_policy = "never",
    })

    self.tabs = {
        quick = { "bolt", "Quick" },
        appearance = { "palette", "Appearance" },
        interface = { "tune", "Interface" },
        services = { "api", "Services" },
        network = { "network_wifi", "Network" },
        bluetooth = { "bluetooth", "Bluetooth" },
        about = { "info", "System" },
    }

    self.active_tab_label = widgets.Label({
        label = "Quick",
        css_classes = { "active-tab-label" },
    })

    local rail = NavigationRail.new(self.tabs, function(key)
        self:switch_tab(key)
    end, "quick", true, TAB_ORDER)
    rail.vexpand = true
    rail:append(widgets.Box({ vexpand = true }))
    rail:append(self.reload_button)

    self.window = widgets.RegularWindow({
        css_classes = { "settings-window" },
        default_width = 1200,
        default_height = 900,
        hide_on_close = true,
        visible = false,
        title = "Exo Settings",
        namespace = "Settings",
        child = widgets.Box({
            vertical = true,
            vexpand = true,
            valign = "fill",
            child = {
                widgets.Box({
                    css_classes = { "header-bar" },
                    spacing = 5,
                    child = {
                        widgets.Label({ label = "settings", css_classes = { "header-title-icon" } }),
                        widgets.Label({ label = "Exo Settings", css_classes = { "header-title" } }),
                        widgets.Label({ label = ">", css_classes = { "breadcrumb-separator" } }),
                        self.active_tab_label,
                    },
                }),
                widgets.Box({
                    vexpand = true,
                    child = {
                        rail:widget(),
                        self.content_scroll,
                    },
                }),
            },
        }),
    })

    self.window:connect("notify::visible", function()
        if self.window.visible then
            if not self._initialized then
                self._initialized = true
                self:switch_tab(self._active_key or "quick")
            else
                local inst = self._tab_instances[self._active_key]
                if inst and inst.update_ui then
                    pcall(function() inst:update_ui() end)
                end
            end
        end
    end)

    return self
end

function Settings:switch_tab(key)
    local tab = self.tabs[key]
    if not tab then return end
    self._active_key = key
    self.active_tab_label.label = tab[2] or tab[1]

    if self.window and not self.window.visible and not self._initialized then
        return
    end
    self._initialized = true

    local cached_widget = self._tab_cache[key]
    if not cached_widget then
        local module = TAB_MODULES[key]
        if module then
            local instance = module.new()
            self._tab_instances[key] = instance
            cached_widget = instance:widget()
            self._tab_cache[key] = cached_widget
        end
    else
        local inst = self._tab_instances[key]
        if inst and inst.update_ui then
            pcall(function() inst:update_ui() end)
        end
    end

    if cached_widget then
        self.content_scroll:set_child(cached_widget)
    end
end

return Settings
