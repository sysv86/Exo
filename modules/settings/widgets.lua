local ignis = require("ignis")
local widgets = ignis.widgets

local Button = require("modules.m3components").Button

local M = {}

local function values_equal(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if not values_equal(a[i], b[i]) then
            return false
        end
    end
    for k, v in pairs(a) do
        if not values_equal(v, b[k]) then
            return false
        end
    end
    return true
end


--- Section heading with an optional leading Material icon.
--- Accepts either `CategoryLabel({ title =, icon = })` or `CategoryLabel(title, icon)`.
---@return table widgets.Box
function M.CategoryLabel(title_or_props, icon_arg)
    local title, icon
    if type(title_or_props) == "table" then
        title = title_or_props.title
        icon = title_or_props.icon
    else
        title = title_or_props
        icon = icon_arg
    end

    local children = {}
    if icon then
        children[#children + 1] = widgets.Label({
            css_classes = { "m3-icon" },
            label = icon,
            justify = "left",
            halign = "start",
        })
    end
    children[#children + 1] = widgets.Label({
        label = title,
        justify = "left",
        halign = "start",
    })

    return widgets.Box({
        css_classes = { "settings-category-label" },
        spacing = 5,
        child = children,
    })
end


--- Mutually exclusive toggle buttons backed by `get_value`/`set_value`.
---
--- `items` entries are `{ label, value }` or `{ label, value, icon }`.
--- Depending on which of `widget_name`/`bar_id` is given, `set_value` is called
--- as `set_value(value)`, `set_value(value, bar_id)` or
--- `set_value(widget_name, value)`.
---@return table widgets.Box
function M.make_toggle_buttons(items, get_value, set_value, on_any_click, widget_name, bar_id)
    local buttons = {}

    local function update_active()
        local current_val = get_value()
        for _, entry in ipairs(buttons) do
            local btn, value = entry[1], entry[2]
            local is_active = values_equal(current_val, value)
            if widget_name then
                is_active = is_active and widget_name ~= nil
            end
            if is_active then
                btn:add_css_class("active")
                btn:add_css_class("filled")
            else
                btn:remove_css_class("active")
                btn:remove_css_class("filled")
            end
        end
    end

    for _, item in ipairs(items) do
        local label, value, icon
        if #item == 3 then
            label, value, icon = item[1], item[2], item[3]
        else
            label, value = item[1], item[2]
            icon = nil
        end

        local btn = Button.button({
            label = label,
            icon = icon,
            on_click = function()
                if bar_id then
                    set_value(value, bar_id)
                elseif widget_name then
                    set_value(widget_name, value)
                else
                    set_value(value)
                end
                update_active()
                if on_any_click then
                    on_any_click()
                end
            end,
            shape = "square",
            hexpand = true,
            halign = "fill",
            size = "xs",
        })

        buttons[#buttons + 1] = { btn, value }
    end

    update_active()

    local children = {}
    for _, entry in ipairs(buttons) do
        children[#children + 1] = entry[1]
    end

    return Button.connected_group(children, {
        homogeneous = false,
        halign = "start",
        hexpand = false,
    })
end

--- Independent (non-exclusive) toggle buttons backed by getter/setter pairs.
--- `items` entries are `{ label, get_bool, set_bool }` or `{ label, get_bool, set_bool, icon }`.
---@return table widgets.Box
function M.make_independent_toggle_buttons(items, on_any_click, bar_id)
    local buttons = {}

    local function update_active()
        for _, entry in ipairs(buttons) do
            local btn, get_bool = entry[1], entry[2]
            if get_bool() then
                btn:add_css_class("active")
                btn:add_css_class("filled")
            else
                btn:remove_css_class("active")
                btn:remove_css_class("filled")
            end
        end
    end

    for _, item in ipairs(items) do
        local label, get_bool, set_bool, icon
        if #item == 4 then
            label, get_bool, set_bool, icon = item[1], item[2], item[3], item[4]
        else
            label, get_bool, set_bool = item[1], item[2], item[3]
            icon = nil
        end

        local btn = Button.button({
            label = label,
            icon = icon,
            on_click = function()
                local new_value = not get_bool()
                if bar_id then
                    set_bool(new_value, bar_id)
                else
                    set_bool(new_value)
                end
                update_active()
                if on_any_click then
                    on_any_click()
                end
            end,
            shape = "square",
            hexpand = true,
            halign = "fill",
            size = "xs",
        })

        buttons[#buttons + 1] = { btn, get_bool }
    end

    update_active()

    local children = {}
    for _, entry in ipairs(buttons) do
        children[#children + 1] = entry[1]
    end

    return Button.connected_group(children, {
        homogeneous = false,
        halign = "start",
        hexpand = false,
    })
end


--- A titled settings row with optional icon, description and trailing widgets.
---@param props table icon, title, description, child, vertical, css_classes
---@return table widgets.Box
function M.SettingsRow(props)
    props = props or {}

    local header = {}
    if props.icon then
        header[#header + 1] = widgets.Label({
            label = props.icon,
            css_classes = { "settings-row-icon" },
            halign = "start",
        })
    end
    if props.title then
        header[#header + 1] = widgets.Label({
            label = props.title,
            css_classes = { "settings-row-title" },
            halign = "start",
        })
    end
    if props.description then
        header[#header + 1] = widgets.Label({
            label = props.description,
            css_classes = { "settings-row-description" },
            halign = "start",
        })
    end

    local children = {
        widgets.Box({
            vertical = true,
            css_classes = { "settings-row-header" },
            valign = "center",
            halign = "fill",
            hexpand = true,
            child = header,
        }),
    }
    for _, child in ipairs(props.child or {}) do
        children[#children + 1] = child
    end

    local classes = { "settings-row" }
    for _, class in ipairs(props.css_classes or {}) do
        classes[#classes + 1] = class
    end

    local extra = {}
    for key, value in pairs(props) do
        if key ~= "icon" and key ~= "title" and key ~= "description"
            and key ~= "child" and key ~= "vertical" and key ~= "css_classes" then
            extra[key] = value
        end
    end
    extra.css_classes = classes
    extra.vertical = props.vertical or false
    extra.hexpand = true
    extra.halign = "fill"
    extra.spacing = 5
    extra.child = children

    return widgets.Box(extra)
end


--- A clickable settings row containing a switch.
--- Setting `can_target = false` on the inner switch ensures clicking directly
--- on the switch pill still activates the parent row Button and triggers
--- `on_change` reliably.
---@param active boolean
---@param on_change fun(switch: table, new_active: boolean)
---@param props table icon, title, description, css_classes
---@return table widgets.Button
function M.SwitchRow(active, on_change, props)
    props = props or {}

    local switch = widgets.Switch({
        active = active and true or false,
        valign = "center",
        halign = "end",
        can_target = false,
        can_focus = false,
    })

    local row_props = {
        vertical = false,
        css_classes = { "switch-row" },
        child = { switch },
        icon = props.icon,
        title = props.title,
        description = props.description,
    }
    for _, class in ipairs(props.css_classes or {}) do
        row_props.css_classes[#row_props.css_classes + 1] = class
    end

    local row_content = M.SettingsRow(row_props)
    row_content:remove_css_class("settings-row")

    local row_btn = widgets.Button({
        child = row_content,
        on_click = function()
            local new_active_state = not switch.active
            switch:set_active(new_active_state)
            if on_change then
                on_change(switch, new_active_state)
            end
        end,
        hexpand = true,
        halign = "fill",
        css_classes = { "settings-row", "row-button" },
    })

    row_btn.switch = switch
    return row_btn
end

return M
