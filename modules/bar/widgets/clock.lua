local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils

local user_settings = require("user_settings")

local Clock = {}
Clock.__index = Clock

local function bar_for(bar_id)
    if bar_id == 0 then
        return user_settings.interface.bar
    end
    return user_settings.interface.bar2
end

function Clock.new()
    local self = setmetatable({}, Clock)

    self.container = widgets.Box({ css_classes = { "clock" }, hexpand = true, vexpand = true })
    self.time_label = widgets.Label({ css_classes = { "time" }, justify = "center" })
    self.separator = widgets.Label({
        css_classes = { "separator" },
        visible = false,
        label = "•",
        hexpand = false,
        vexpand = false,
    })
    self.date_label = widgets.Label({ css_classes = { "date" }, justify = "center" })
    self.date_separator = widgets.Separator({ vertical = false, hexpand = false, vexpand = false })
    self.month_label = widgets.Label({ css_classes = { "month" }, justify = "center", visible = false })

    self.container:append(self.time_label)
    self.container:append(self.separator)
    self.container:append(self.date_label)
    self.container:append(self.date_separator)
    self.container:append(self.month_label)

    utils.Poll(1000, function()
        self:update_labels()
    end)

    self:update_layout()
    return self
end

function Clock:update_labels()
    local settings = user_settings.interface.modules.options
    local bar = bar_for(user_settings.interface.modules.bar_id.clock)
    local is_vertical = bar.vertical
    local day_month_swapped = settings.day_month_swapped
    local military_time = settings.military_time

    local time_format, date_format, month_format
    if is_vertical then
        time_format = military_time and "%H\n%M" or "%I\n%M"
        date_format = day_month_swapped and "%m" or "%d"
        month_format = day_month_swapped and "%d" or "%m"
    else
        time_format = military_time and "%H:%M" or "%I:%M %p"
        date_format = day_month_swapped and "%a %b %d" or "%a %d %b"
        month_format = ""
    end

    self.time_label:set_label(os.date(time_format))
    self.date_label:set_label(os.date(date_format))
    self.month_label:set_label(month_format ~= "" and os.date(month_format) or "")
end

function Clock:update_layout()
    local settings = user_settings.interface.modules.options
    local bar_id = user_settings.interface.modules.bar_id.clock
    local bar = bar_for(bar_id)
    local is_vertical = bar.vertical
    local compact_mode = bar.density
    local date_visible = settings.show_date

    self.container:set_halign("fill")
    self.container:set_valign("fill")
    self.container:set_vertical(is_vertical)

    if date_visible then
        self.date_label:set_visible(true)
        if is_vertical then
            self.separator:set_visible(true)
        elseif compact_mode == 0 then
            self.separator:set_visible(false)
        else
            self.separator:set_visible(true)
        end
        if is_vertical then
            self.date_separator:set_visible(true)
            self.month_label:set_visible(true)
        else
            self.date_separator:set_visible(false)
            self.month_label:set_visible(false)
        end
    else
        self.separator:set_visible(false)
        self.date_label:set_visible(false)
        self.date_separator:set_visible(false)
        self.month_label:set_visible(false)
    end

    if is_vertical then
        self.container:set_spacing(0)
        self.container:set_homogeneous(false)
        self.time_label:set_valign("center")
    elseif compact_mode == 0 then
        self.container:set_spacing(0)
        self.container:set_homogeneous(true)
        if date_visible then
            self.time_label:set_valign("end")
            self.date_label:set_valign("start")
        else
            self.time_label:set_valign("center")
            self.date_label:set_valign("center")
        end
        self.container:set_vertical(true)
    elseif compact_mode == 1 then
        self.container:set_spacing(10)
        self.container:set_homogeneous(false)
        self.time_label:set_valign("center")
        self.date_label:set_valign("center")
        self.container:set_vertical(false)
    elseif compact_mode == 2 then
        self.container:set_spacing(6)
        self.container:set_homogeneous(false)
        self.time_label:set_valign("center")
        self.date_label:set_valign("center")
        self.container:set_vertical(false)
    elseif compact_mode == 3 then
        self.container:set_spacing(4)
        self.container:set_homogeneous(false)
        self.time_label:set_valign("center")
        self.container:set_vertical(false)
    end
end

function Clock:widget()
    return self.container
end

return Clock
