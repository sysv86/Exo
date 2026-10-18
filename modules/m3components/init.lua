local Ignis = require("ignis")
local widgets = Ignis.widgets
local widget_proxy = require("widget_proxy")
local Shapes = require("modules.m3components.shapes")
local button_morph = require("modules.m3components.button_morph")

local M = {}

M.Shapes = Shapes
M.ShapeBadge = Shapes.ShapeBadge
M.LoadingIndicator = Shapes.LoadingIndicator


local GAPS = { xs = 6, s = 8, m = 10, l = 12, xl = 16 }

local Button = {}

--- Builds a Material 3 Expressive button.
---@param props table icon, label, on_click, type, size, shape, css_classes,
---  ialign, vertical, plus any `widgets.Button` property
---@return table widgets.Button
function Button.button(props)
    props = props or {}
    local icon = props.icon
    local label = props.label
    local has_icon = (icon ~= nil and icon ~= "" and icon ~= false)
    local has_label = (label ~= nil and label ~= "" and label ~= false)
    local on_click = props.on_click or function() end
    local button_type = props.type or props.variant or "tonal"
    local size = props.size or "s"
    local shape = props.shape or "round"
    local ialign = props.ialign or "center"
    local vertical = props.vertical or false

    local classes = { "m3-button", button_type, size, shape }
    for _, class in ipairs(props.css_classes or {}) do
        classes[#classes + 1] = class
    end

    local children = {}
    if has_icon then
        children[#children + 1] = widgets.Label({
            label = icon,
            css_classes = { "m3-button-icon" },
            halign = "center",
            hexpand = false,
        })
        if not has_label then
            classes[#classes + 1] = "icon-only"
        end
    end
    if has_label then
        children[#children + 1] = widgets.Label({
            label = tostring(label),
            css_classes = { "m3-button-label" },
        })
    end

    local gap = (has_icon and has_label) and (GAPS[size] or 8) or 0

    local content = widgets.Box({
        vertical = vertical,
        spacing = gap,
        child = children,
        halign = ialign,
        valign = "center",
        css_classes = { "m3-pad" },
    })

    local extra = {}
    for key, value in pairs(props) do
        if key ~= "icon" and key ~= "label" and key ~= "on_click" and key ~= "type"
            and key ~= "variant" and key ~= "size" and key ~= "shape"
            and key ~= "css_classes" and key ~= "ialign" and key ~= "vertical" then
            extra[key] = value
        end
    end
    extra.css_classes = classes
    extra.on_click = on_click
    local button = widgets.Button(extra)
    button.child = button_morph.attach_layout(button, content)

    return button
end

--- Wraps a list of buttons into a Material 3 Expressive "connected button group"
--- with 2dp inner spacing and positional segment classes (`segment-first`, `segment-middle`, `segment-last`).
---@param children table[]
---@param props? table
---@return table widgets.Box
function Button.connected_group(children, props)
    props = props or {}
    local n = #(children or {})
    for i, btn in ipairs(children or {}) do
        if btn and btn.add_css_class then
            btn:add_css_class("connected-segment")
            if n == 1 then
                btn:add_css_class("segment-single")
            elseif i == 1 then
                btn:add_css_class("segment-first")
            elseif i == n then
                btn:add_css_class("segment-last")
            else
                btn:add_css_class("segment-middle")
            end
        end
    end

    local extra = {}
    for key, value in pairs(props) do
        extra[key] = value
    end
    extra.vertical = false
    extra.vexpand = false
    extra.spacing = props.spacing or 2
    local classes = { "connected-button-group" }
    for _, c in ipairs(props.css_classes or {}) do
        classes[#classes + 1] = c
    end
    extra.css_classes = classes
    extra.child = children
    return widgets.Box(extra)
end

--- Replaces the icon of a button produced by `Button.button`.
---@param button table
---@param icon string
function Button.set_icon(button, icon)
    local child = button and button.get_child and button:get_child()
    if not child then return end

    local content = child
    pcall(function()
        local overlays = child:get_overlays()
        if overlays and overlays[1] then
            content = overlays[1]
        end
    end)

    local icon_label = content.get_first_child and content:get_first_child()
    if icon_label and icon_label:has_css_class("m3-button-icon") then
        icon_label:set_label(icon)
    end
end

M.Button = Button

--- Attaches the cairo morph shell to an already-built `.m3-button`.
---@param button table
---@param spec? table explicit halo spec { bg, ink, hover_bg, hover_ink, radius = {rest, hover, press, active} }
M.enhance_button = function(button, spec)
    return button_morph.enhance(button, spec)
end


local SplitButton = {}

--- Builds an M3 Expressive SplitButton (leading action + 2dp gap + trailing menu chevron).
---@param props table { icon?: string, label: string, type?: string, size?: string, on_click?: function, on_menu_click?: function, menu_open?: boolean }
---@return table widgets.Box
function SplitButton.new(props)
    props = props or {}
    local size = props.size or "s"
    local btype = props.type or "filled"
    local menu_open = props.menu_open or false

    local lead_btn = Button.button({
        icon = props.icon,
        label = props.label,
        type = btype,
        size = size,
        shape = "square",
        css_classes = { "m3-split-leading" },
        on_click = props.on_click,
    })

    local chev_lbl = widgets.Label({
        label = menu_open and "expand_less" or "expand_more",
        css_classes = { "m3-button-icon", "m3-split-chevron" },
    })

    local trail_btn = widgets.Button({
        css_classes = { "m3-button", btype, size, "icon-only", "m3-split-trailing", menu_open and "open" or nil },
    })
    trail_btn.child = button_morph.attach_layout(trail_btn, widgets.Box({
        child = { chev_lbl },
        css_classes = { "m3-pad" },
        halign = "center",
        valign = "center",
    }))

    trail_btn.on_click = function(self)
        menu_open = not menu_open
        self:toggle_css_class("open", menu_open)
        chev_lbl.label = menu_open and "expand_less" or "expand_more"
        if props.on_menu_click then
            props.on_menu_click(self, menu_open)
        end
    end

    return widgets.Box({
        spacing = 2,
        halign = props.halign or "center",
        valign = props.valign or "center",
        css_classes = { "m3-split-button" },
        child = { lead_btn, trail_btn },
    })
end

M.SplitButton = SplitButton


local FloatingToolbar = {}

function FloatingToolbar.new(props)
    props = props or {}
    local variant = props.variant or "standard" -- "standard" | "vibrant"
    local children = {}

    for _, item in ipairs(props.items or {}) do
        if item.separator then
            children[#children + 1] = widgets.Separator({ vertical = true, css_classes = { "m3-toolbar-sep" } })
        else
            children[#children + 1] = Button.button({
                icon = item.icon,
                label = item.label,
                type = item.active and "filled" or "text",
                size = item.size or "s",
                tooltip_text = item.tooltip_text,
                css_classes = item.active and { "active" } or {},
                on_click = item.on_click,
            })
        end
    end

    return widgets.Box({
        spacing = 4,
        halign = props.halign or "center",
        valign = props.valign or "center",
        css_classes = { "m3-floating-toolbar", variant },
        child = children,
    })
end

M.FloatingToolbar = FloatingToolbar


local NewButton = {}
NewButton.__index = NewButton

local NEW_BUTTON_CLASSES = {
    "elevated", "filled", "tonal", "outlined", "surface", "text", "danger",
    "xs", "s", "m", "l", "xl",
    "round", "square", "icon-only",
}

---@param props table
---@return table
function NewButton.new(props)
    props = props or {}

    local self = setmetatable({
        _icon = props.icon or "",
        _label = props.label or "",
        _type = props.type or "tonal",
        _size = props.size or "s",
        _shape = props.shape or "round",
        _ialign = props.ialign or "center",
        _vertical = props.vertical or false,
    }, NewButton)

    local gap = GAPS[self._size] or 8

    self.button_icon = widgets.Label({
        label = self._icon,
        css_classes = { "m3-button-icon" },
        halign = "center",
        hexpand = false,
        visible = false,
    })
    self.button_label = widgets.Label({
        label = self._label,
        css_classes = { "m3-button-label" },
        visible = false,
    })

    self.container = widgets.Box({
        vertical = self._vertical,
        spacing = gap,
        halign = self._ialign,
        valign = "center",
        child = { self.button_icon, self.button_label },
    })

    local button_props = {}
    for key, value in pairs(props) do
        if key ~= "icon" and key ~= "label" and key ~= "type" and key ~= "size"
            and key ~= "shape" and key ~= "ialign" and key ~= "vertical" then
            button_props[key] = value
        end
    end
    button_props.child = nil
    self._button = widgets.Button(button_props)
    self._button.child = button_morph.attach_layout(self._button, self.container)

    setmetatable(self, widget_proxy.proxy(NewButton, self._button))

    self:update()
    return self
end

function NewButton:set_icon(value)
    self._icon = value
    self.button_icon:set_label(value)
    self:update()
end

function NewButton:set_label(value)
    self._label = value
    self.button_label:set_label(value)
    self:update()
end

function NewButton:set_type(value)
    self._type = value
    self:update()
end

function NewButton:set_size(value)
    self._size = value
    self.container:set_spacing(GAPS[value] or 8)
    self:update()
end

function NewButton:set_shape(value)
    self._shape = value
    self:update()
end

function NewButton:set_ialign(value)
    self._ialign = value
    self.container:set_halign(value)
end

function NewButton:set_vertical(value)
    self._vertical = value
    self.container:set_vertical(value)
end

function NewButton:update()
    for _, class in ipairs(NEW_BUTTON_CLASSES) do
        self._button:remove_css_class(class)
    end

    self._button:add_css_class("m3-button")
    self._button:add_css_class(self._type)
    self._button:add_css_class(self._size)
    self._button:add_css_class(self._shape)
    if self._icon ~= "" and self._label == "" then
        self._button:add_css_class("icon-only")
    end

    self.button_icon:set_visible(self._icon ~= "")
    self.button_label:set_visible(self._label ~= "")
end

function NewButton:widget()
    return self._button
end

M.NewButton = NewButton


local Slider = {}

--- Builds a Material 3 Expressive slider (optional leading icon + `Gtk.Scale`).
---@param props table min, max, value, vertical, step, icon, on_change
---@return table widgets.Box
function Slider.slider(props)
    props = props or {}
    local icon_widget = nil
    if props.icon then
        icon_widget = widgets.Label({
            css_classes = { "m3-slider-icon", "m3-icon" },
            label = props.icon,
            valign = "center",
        })
    end

    local children = {}
    if icon_widget then
        children[#children + 1] = icon_widget
    end
    children[#children + 1] = widgets.Scale({
        min = props.min,
        max = props.max,
        value = props.value,
        step = props.step or 1.0,
        vertical = props.vertical or false,
        halign = "fill",
        hexpand = true,
        css_classes = { "m3-expressive-slider" },
        on_change = props.on_change,
    })

    local extra = {}
    for key, value in pairs(props) do
        if key ~= "min" and key ~= "max" and key ~= "value" and key ~= "vertical"
            and key ~= "step" and key ~= "icon" and key ~= "on_change" then
            extra[key] = value
        end
    end
    extra.css_classes = { "m3-slider" }
    extra.spacing = 12
    extra.halign = "fill"
    extra.hexpand = true
    extra.child = children
    return widgets.Box(extra)
end

M.Slider = Slider


local NavigationRail = {}
NavigationRail.__index = NavigationRail

function NavigationRail.new(tabs, on_select, default, vertical, tab_order)
    if vertical == nil then vertical = true end

    local self = setmetatable({
        _on_select = on_select,
        _buttons = {},
    }, NavigationRail)

    local ordered_keys = tab_order
    if not ordered_keys then
        ordered_keys = {}
        for k in pairs(tabs) do
            ordered_keys[#ordered_keys + 1] = k
        end
        table.sort(ordered_keys)
    end

    local children = {}
    for _, key in ipairs(ordered_keys) do
        local value = tabs[key]
        if value then
            local icon, label = value[1], value[2]
            local btn = Button.button({
                icon = icon,
                label = label,
                ialign = "center",
                valign = "center",
                css_classes = { "rail-button" },
                vertical = true,
                on_click = function()
                    self:select(key)
                end,
            })
            self._buttons[key] = btn
            children[#children + 1] = btn
        end
    end

    self._box = widgets.Box({
        css_classes = { "navigation-rail" },
        vertical = vertical,
        spacing = 6,
        child = children,
    })

    setmetatable(self, widget_proxy.proxy(NavigationRail, self._box))

    if default then
        self:select(default)
    end

    return self
end

function NavigationRail:select(key)
    for name, btn in pairs(self._buttons) do
        if name == key then
            btn:add_css_class("selected")
        else
            btn:remove_css_class("selected")
        end
    end
    if self._on_select then
        self._on_select(key)
    end
end

function NavigationRail:widget()
    return self._box
end

M.NavigationRail = NavigationRail

return M
