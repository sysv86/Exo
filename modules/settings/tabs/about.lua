local ignis = require("ignis")
local widgets = ignis.widgets
local services = ignis.services

local settings_widgets = require("modules.settings.widgets")

local CategoryLabel = settings_widgets.CategoryLabel
local SettingsRow = settings_widgets.SettingsRow

local fetch = services.FetchService.get_default()

--- Rounds `value` to `digits` decimal places (Python's `round(value, digits)`).
---@param value number
---@param digits? number
---@return number
local function round(value, digits)
    local mult = 10 ^ (digits or 0)
    return math.floor(value * mult + 0.5) / mult
end


local SoftwareCategory = {}
SoftwareCategory.__index = SoftwareCategory

function SoftwareCategory.new()
    local self = setmetatable({}, SoftwareCategory)

    local os_row_children = {}
    if fetch.os_logo then
        os_row_children[#os_row_children + 1] = widgets.Picture({
            image = fetch.os_logo,
            css_classes = { "settings-logo" },
            height = 30,
        })
    end

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Software" }),
            SettingsRow({
                title = "Operating System",
                description = fetch.os_name,
                vertical = false,
                child = os_row_children,
            }),
            widgets.Separator(),
            SettingsRow({
                title = "Desktop",
                description = fetch.current_desktop,
            }),
            widgets.Separator(),
            SettingsRow({
                title = "Hostname",
                description = (fetch.hostname or ""):gsub("\n", ""),
            }),
        },
    })

    return self
end

function SoftwareCategory:widget()
    return self.box
end


local AppearanceCategory = {}
AppearanceCategory.__index = AppearanceCategory

function AppearanceCategory.new()
    local self = setmetatable({}, AppearanceCategory)

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Appearance" }),
            SettingsRow({ title = "GTK Theme", description = fetch.gtk_theme }),
            widgets.Separator(),
            SettingsRow({ title = "Icon Theme", description = fetch.icon_theme }),
        },
    })

    return self
end

function AppearanceCategory:widget()
    return self.box
end


local HardwareCategory = {}
HardwareCategory.__index = HardwareCategory

function HardwareCategory.new()
    local self = setmetatable({}, HardwareCategory)

    self.box = widgets.Box({
        css_classes = { "settings-category" },
        vertical = true,
        spacing = 0,
        child = {
            CategoryLabel({ title = "Hardware" }),
            SettingsRow({ title = "CPU", description = fetch.cpu }),
            widgets.Separator(),
            SettingsRow({
                title = "RAM",
                description = tostring(round(fetch.mem_total / 1024 / 1024, 2)) .. " GiB",
            }),
        },
    })

    return self
end

function HardwareCategory:widget()
    return self.box
end


local AboutTab = {}
AboutTab.__index = AboutTab

function AboutTab.new()
    local self = setmetatable({}, AboutTab)

    self.box = widgets.Box({
        css_classes = { "settings-body" },
        vertical = true,
        spacing = 8,
        hexpand = false,
        halign = "center",
        width_request = 800,
        child = {
            SoftwareCategory.new():widget(),
            AppearanceCategory.new():widget(),
            HardwareCategory.new():widget(),
        },
    })

    return self
end

function AboutTab:widget()
    return self.box
end

return AboutTab
